from __future__ import annotations

import importlib.util
from importlib.machinery import SourceFileLoader
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPOSITORY_ROOT / "home/.local/bin/git-local"
MODULE_LOADER = SourceFileLoader("git_local", str(SCRIPT))
MODULE_SPEC = importlib.util.spec_from_loader("git_local", MODULE_LOADER)
assert MODULE_SPEC and MODULE_SPEC.loader
git_local = importlib.util.module_from_spec(MODULE_SPEC)
sys.modules[MODULE_SPEC.name] = git_local
MODULE_SPEC.loader.exec_module(git_local)


def run_git(*arguments: str, cwd: Path | None = None) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def initialise_repository(path: Path, *, branch: str = "main") -> None:
    path.mkdir(parents=True)
    run_git("init", "-q", cwd=path)
    run_git("config", "user.name", "Test User", cwd=path)
    run_git("config", "user.email", "test@example.invalid", cwd=path)
    run_git("checkout", "-q", "-b", branch, cwd=path)
    (path / "README.md").write_text("initial\n", encoding="utf-8")
    run_git("add", "README.md", cwd=path)
    run_git("commit", "-q", "-m", "initial", cwd=path)


class ReferenceTests(unittest.TestCase):
    def test_shorthand_defaults_to_github_ssh(self) -> None:
        reference = git_local.parse_repository_reference("ltekton/lskills-older")
        self.assertEqual(
            reference,
            git_local.RepositoryReference("github.com", "ltekton", "lskills-older"),
        )

    def test_host_shorthand_and_urls(self) -> None:
        cases = {
            "github.tools.sap/AI4Sustainability/podtrans": ("github.tools.sap", "AI4Sustainability", "podtrans", "ssh"),
            "https://github.com/ltekton/lskills-older.git": ("github.com", "ltekton", "lskills-older", "https"),
            "git@github.com:ltekton/lskills-older.git": ("github.com", "ltekton", "lskills-older", "ssh"),
            "ssh://git@github.com/ltekton/lskills-older.git": ("github.com", "ltekton", "lskills-older", "ssh"),
        }
        for value, expected in cases.items():
            with self.subTest(value=value):
                reference = git_local.parse_repository_reference(value)
                self.assertEqual(
                    (reference.host, reference.owner, reference.name, reference.scheme),
                    expected,
                )

    def test_rejects_unsafe_or_ambiguous_references(self) -> None:
        invalid = (
            "",
            " owner/repo",
            "owner/repo ",
            "owner",
            "host/owner/repo/extra",
            "host/../repo",
            "host/owner/..",
            "https://github.com/owner/repo?ref=main",
            "https://github.com:443/owner/repo",
            "https://github.com/owner/repo/",
        )
        for value in invalid:
            with self.subTest(value=value), self.assertRaises(ValueError):
                git_local.parse_repository_reference(value)

    def test_clone_url_preserves_input_transport(self) -> None:
        https = git_local.parse_repository_reference("https://example.com/a/b")
        ssh = git_local.parse_repository_reference("example.com/a/b")
        self.assertEqual(git_local.clone_url(https), "https://example.com/a/b.git")
        self.assertEqual(git_local.clone_url(ssh), "git@example.com:a/b.git")

    def test_origin_parser_rejects_local_urls(self) -> None:
        self.assertEqual(
            git_local.parse_origin_url("git@github.com:owner/repo.git"),
            git_local.RepositoryReference("github.com", "owner", "repo"),
        )
        self.assertIsNone(git_local.parse_origin_url("/tmp/repo"))

    def test_lscolors_reads_directory_and_repository_styles(self) -> None:
        with patch.dict(
            os.environ,
            {"LS_COLORS": "di=38;5;33:ex=38;5;70", "EZA_COLORS": "di=38;5;1:ex=38;5;2"},
        ):
            colors = git_local.LsColors.from_environment()
        self.assertEqual(colors.style("di"), "38;5;33")
        self.assertEqual(colors.style("ex"), "38;5;70")

    def test_prompt_colors_read_starship_palette(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "starship.toml"
            config.write_text(
                'palette = "test"\n'
                "[palettes.test]\n"
                'branch = "#112233"\n'
                'status = "#445566"\n',
                encoding="utf-8",
            )
            with patch.dict(os.environ, {"STARSHIP_CONFIG": str(config)}):
                colors = git_local.PromptColors.from_environment()
        self.assertEqual(colors.style("branch"), "38;2;17;34;51")
        self.assertEqual(colors.style("status"), "38;2;68;85;102")


class CloneTests(unittest.TestCase):
    def test_uses_gh_for_supported_hosts_without_a_shell(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            calls: list[tuple[list[str], dict[str, object]]] = []

            def runner(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
                calls.append((command, kwargs))
                return subprocess.CompletedProcess(command, 0, "", "")

            reference = git_local.parse_repository_reference("owner/repo")
            result = git_local.clone_repository(reference, root, runner=runner, which=lambda _: "/bin/gh")

        self.assertEqual(result, 0)
        self.assertEqual(len(calls), 1)
        command, kwargs = calls[0]
        self.assertEqual(
            command,
            [
                "gh",
                "repo",
                "clone",
                "owner/repo",
                str(root / "github.com/owner/repo"),
                "--no-upstream",
                "--",
                "--recurse-submodules",
            ],
        )
        self.assertIsInstance(kwargs["env"], dict)
        self.assertEqual(kwargs["env"]["GH_HOST"], "github.com")  # type: ignore[index]
        self.assertNotIn("shell", kwargs)

    def test_falls_back_to_git_for_other_hosts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            calls: list[list[str]] = []

            def runner(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
                calls.append(command)
                return subprocess.CompletedProcess(command, 0, "", "")

            reference = git_local.parse_repository_reference("example.com/owner/repo")
            git_local.clone_repository(reference, root, runner=runner, which=lambda _: None)

        self.assertEqual(
            calls,
            [[
                "git",
                "clone",
                "--recurse-submodules",
                "--",
                "git@example.com:owner/repo.git",
                str(root / "example.com/owner/repo"),
            ]],
        )

    def test_rejects_existing_target_before_running_clone(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "github.com/owner/repo"
            target.mkdir(parents=True)
            runner = Mock()
            reference = git_local.parse_repository_reference("owner/repo")
            with self.assertRaises(git_local.ExistingTargetError):
                git_local.clone_repository(reference, root, runner=runner)
        runner.assert_not_called()


class StatusTests(unittest.TestCase):
    def test_porcelain_status_counts_changes_and_conflicts(self) -> None:
        output = " M modified\nM  staged\nR  renamed\n D deleted\n?? new\nUU conflict\n"
        self.assertEqual(git_local._parse_porcelain_status(output), (5, 1, 1))
        details = git_local._parse_porcelain_details(output)
        self.assertEqual(details.tracked_changes, 5)
        self.assertEqual(details.staged_changes, 1)
        self.assertEqual(details.modified_changes, 1)
        self.assertEqual(details.renamed_changes, 1)
        self.assertEqual(details.deleted_changes, 1)
        self.assertEqual(details.untracked, 1)
        self.assertEqual(details.conflicts, 1)

    def test_status_fixtures(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "git"
            clean = root / "github.com/acme/clean"
            modified = root / "github.com/acme/modified"
            untracked = root / "github.com/acme/untracked"
            detached = root / "github.com/acme/detached"
            for repository in (clean, modified, untracked, detached):
                initialise_repository(repository)

            (modified / "README.md").write_text("changed\n", encoding="utf-8")
            (untracked / "new.txt").write_text("new\n", encoding="utf-8")
            run_git("checkout", "--detach", "-q", cwd=detached)

            clean_status = git_local.repository_status(clean, root)
            modified_status = git_local.repository_status(modified, root)
            untracked_status = git_local.repository_status(untracked, root)
            detached_status = git_local.repository_status(detached, root)

        self.assertFalse(clean_status.dirty)
        self.assertEqual(clean_status.branch, "main")
        self.assertFalse(clean_status.has_upstream)
        self.assertEqual(clean_status.push_status, "no-upstream")
        self.assertEqual((modified_status.tracked_changes, modified_status.untracked), (1, 0))
        self.assertEqual(modified_status.git_status, "!1")
        self.assertEqual((untracked_status.tracked_changes, untracked_status.untracked), (0, 1))
        self.assertEqual(untracked_status.git_status, "?1")
        self.assertTrue(detached_status.detached)
        self.assertTrue(detached_status.branch.startswith("detached@"))
        self.assertEqual(detached_status.push_status, "detached")

    def test_diverged_repository_reports_ahead_and_behind(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            remote = base / "remote.git"
            seed = base / "seed"
            local = base / "git/github.com/acme/diverged"
            other = base / "other"

            run_git("init", "--bare", "-q", str(remote))
            initialise_repository(seed)
            run_git("remote", "add", "origin", str(remote), cwd=seed)
            run_git("push", "-q", "-u", "origin", "main", cwd=seed)
            local.parent.mkdir(parents=True)
            run_git("clone", "-q", str(remote), str(local))
            run_git("config", "user.name", "Test User", cwd=local)
            run_git("config", "user.email", "test@example.invalid", cwd=local)
            run_git("checkout", "-q", "main", cwd=local)

            (local / "local.txt").write_text("local\n", encoding="utf-8")
            run_git("add", "local.txt", cwd=local)
            run_git("commit", "-q", "-m", "local", cwd=local)

            run_git("clone", "-q", str(remote), str(other))
            run_git("config", "user.name", "Test User", cwd=other)
            run_git("config", "user.email", "test@example.invalid", cwd=other)
            (other / "remote.txt").write_text("remote\n", encoding="utf-8")
            run_git("add", "remote.txt", cwd=other)
            run_git("commit", "-q", "-m", "remote", cwd=other)
            run_git("push", "-q", "origin", "main", cwd=other)
            run_git("fetch", "-q", "origin", "main", cwd=local)

            status = git_local.repository_status(local, base / "git")

        self.assertEqual((status.ahead, status.behind), (1, 1))
        self.assertEqual(status.push_status, "diverged(↑1 ↓1)")
        self.assertEqual(status.git_status, "⇕1/1")
        self.assertTrue(status.origin_matches is False)

    def test_git_status_uses_prompt_symbols(self) -> None:
        status = git_local.RepositoryStatus(
            Path("/tmp/git/host/owner/repo"),
            "main",
            tracked_changes=5,
            staged_changes=1,
            modified_changes=1,
            renamed_changes=1,
            deleted_changes=1,
            untracked=1,
            conflicts=1,
            ahead=2,
            has_upstream=True,
        )
        self.assertEqual(status.git_status, "=1✘1»1!1+1?1⇡2")

    def test_git_status_uses_prompt_push_symbols(self) -> None:
        cases = (
            ({"has_upstream": True}, ""),
            ({"has_upstream": True, "ahead": 1}, "⇡1"),
            ({"has_upstream": True, "behind": 2}, "⇣2"),
            ({"has_upstream": True, "ahead": 1, "behind": 2}, "⇕1/2"),
            ({"has_upstream": False}, ""),
        )
        for fields, expected in cases:
            with self.subTest(fields=fields):
                status = git_local.RepositoryStatus(Path("/tmp/repo"), "main", **fields)
                self.assertEqual(status.git_status, expected)

    def test_origin_path_mismatch_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "git"
            repository = root / "github.com/acme/local-name"
            initialise_repository(repository)
            run_git("remote", "add", "origin", "git@github.com:acme/other-name.git", cwd=repository)
            status = git_local.repository_status(repository, root)
        self.assertFalse(status.origin_matches)


class TreeTests(unittest.TestCase):
    def test_render_tree_preserves_hierarchy_and_status(self) -> None:
        root = Path("/tmp/git")
        statuses = [
            git_local.RepositoryStatus(
                root / "github.com/acme/clean",
                "main",
                has_upstream=True,
                origin_matches=True,
            ),
            git_local.RepositoryStatus(
                root / "github.com/acme/dirty",
                "feature/test",
                tracked_changes=2,
                modified_changes=2,
                untracked=1,
                has_upstream=True,
                origin_matches=True,
            ),
            git_local.RepositoryStatus(
                root / "github.tools.sap/team/work",
                "main",
                has_upstream=True,
                origin_matches=True,
            ),
        ]
        output = "\n".join(git_local.render_tree(root, statuses))
        self.assertIn("github.com", output)
        self.assertIn("acme", output)
        self.assertIn("clean   main", output)
        self.assertIn("dirty   feature/test !2?1", output)
        self.assertIn("github.tools.sap", output)

    def test_render_tree_colors_names_branch_and_status_like_prompt(self) -> None:
        root = Path("/tmp/git")
        status = git_local.RepositoryStatus(
            root / "github.com/acme/repo",
            "main",
            modified_changes=1,
            has_upstream=True,
            origin_matches=True,
        )
        output = "\n".join(
            git_local.render_tree(
                root,
                [status],
                color=True,
                ls_colors=git_local.LsColors({"di": "38;5;33", "ex": "38;5;70"}),
                prompt_colors=git_local.PromptColors(
                    {"branch": "#112233", "status": "#445566"}
                ),
            )
        )
        self.assertIn("\033[38;5;33mgithub.com\033[0m", output)
        self.assertIn("\033[38;5;70mrepo\033[0m", output)
        self.assertIn("\033[38;2;17;34;51m main\033[0m", output)
        self.assertIn("\033[38;2;68;85;102m!1\033[0m", output)

    def test_render_tree_can_explain_an_empty_filter(self) -> None:
        output = git_local.render_tree(Path("/tmp/git"), [], empty_label="no dirty repositories")
        self.assertEqual(output[-1], "└── (no dirty repositories)")

    def test_find_repositories_detects_worktrees(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repository = root / "host/owner/repo"
            repository.mkdir(parents=True)
            (repository / ".git").write_text("gitdir: /tmp/worktree\n", encoding="utf-8")
            self.assertEqual(git_local.find_repositories(root), [repository])


class IntegrationTests(unittest.TestCase):
    def test_uv_script_runs_and_git_discovers_external_subcommand(self) -> None:
        if shutil.which("uv") is None:
            self.skipTest("uv is required to execute git-local")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "git"
            initialise_repository(root / "github.com/acme/repo")
            environment = os.environ.copy()
            environment["PATH"] = f"{SCRIPT.parent}{os.pathsep}{environment['PATH']}"
            environment["LS_COLORS"] = "di=38;5;33:ex=38;5;70"
            environment["EZA_COLORS"] = ""
            result = subprocess.run(
                ["git", "local", "list", "--color", str(root)],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=environment,
            )
            plain_result = subprocess.run(
                ["git", "local", "list", "--no-color", str(root)],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=environment,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("repo\033[0m  \033[", result.stdout)
        self.assertIn(" main", result.stdout)
        self.assertIn("\033[38;5;33mgithub.com\033[0m", result.stdout)
        self.assertIn("\033[38;5;70mrepo\033[0m", result.stdout)
        self.assertEqual(plain_result.returncode, 0, plain_result.stderr)
        self.assertIn("repo   main", plain_result.stdout)
        self.assertNotIn("\033[", plain_result.stdout)


if __name__ == "__main__":
    unittest.main()
