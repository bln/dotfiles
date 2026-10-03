# Mise-generated Git identity files

Date: 2026-10-04

## Question

Can the repository replace the README's manual Git identity-file setup with
mise dotfile templates backed by `[bootstrap.secrets]` and
`--prompt-secrets`?

## Short answer

Yes. The pieces compose cleanly:

1. Declare four logical inputs under `[bootstrap.secrets]`.
2. Put two template sources outside `home/`, because the existing `home/`
   entry walks and symlinks its tracked files.
3. Add explicit `mode = "template"` entries for the two identity-file targets.
4. Render the values with `secret(name = "...")`.
5. Run `mise bootstrap --prompt-secrets` or `mise dot apply --prompt-secrets`
   for an attended setup.

The important limitation is that `--prompt-secrets` is not a persistence
mechanism. Prompted values stay in memory and are not exported or saved by
mise. A later template render normally needs the values supplied again, either
through an environment-backed secret provider or another interactive
`--prompt-secrets` run.

There is a workable exception for this use case: the template can check whether
the target already exists, return its current contents with `read_file()`, and
call `secret()` only when the target is missing. That makes the local identity
file the persistence boundary. It is a deliberate "bootstrap if missing"
policy rather than a normal declarative template policy.

## Current repository shape

`home/.config/git/config` includes:

- `~/.config/git/identity-personal` for the default identity.
- `~/.config/git/identity-work` when a remote matches `github.tools.sap`.

The README currently tells the user to create those files with four
`git config --file` commands. The repository's root `.gitignore` also ignores
`home/.config/git/identity-*`, so those files are intentionally machine-local.

The main dotfile declaration is currently:

```toml
[dotfiles]
"~" = {
  source = "home",
  mode = "symlink-each",
  manifest = "git",
}
```

That entry only deploys Git-tracked files under `home/`. A template source put
inside `home/` would itself be considered for deployment, normally producing a
second target such as `identity-personal.tmpl`. An explicit exclusion could
make that work, but a separate repository-root `templates/` directory is
clearer and avoids changing the broad home mapping.

## Official behavior

### Dotfile templates

A dotfile entry with `mode = "template"` renders a source file into the target.
Relative source paths are relative to the configuration file, so this
repository can use sources such as `templates/git/identity-personal.tmpl`.
`permissions = "0600"` is supported for template files and should be explicit:
a checked-in source file would otherwise normally provide more permissive
source permissions.

Templates can call the bootstrap-secret function:

```jinja
{{ secret(name="logical_name") }}
```

`mise dot status`, `mise dot diff`, and `mise dot apply` render template
entries. Secret values are redacted from mise's output. `--prompt-secrets` is
available on these dotfile operations, as well as `mise bootstrap` and
`mise bootstrap plan`.

The template documentation warns that `secret()` inserts the value literally;
it does not quote or escape it for the destination format. Git names and
addresses should therefore be constrained to ordinary single-line values, or
the template needs format-specific escaping.

### Bootstrap secret declarations

`[bootstrap.secrets]` maps a logical name to an environment variable without
putting the value in `mise.toml`:

```toml
[bootstrap.secrets]
git_personal_name = {
  env = "GIT_PERSONAL_NAME",
  description = "Personal Git user name",
}
```

The table form supports `env`, `description`, and `allow_empty`. Empty values
are rejected by default, which is appropriate for identity fields. mise only
resolves declarations referenced by the selected templates. During a full
bootstrap, referenced inputs are resolved and templates rendered before
bootstrap mutations begin, so a missing input does not leave an earlier phase
partially applied.

Without a value in the environment, `--prompt-secrets` starts a hidden,
interactive prompt. The prompt uses the declaration's `description` when one
is present. Prompting requires an attended terminal; it is not suitable for a
non-interactive CI job.

The environment is the provider boundary. Values can come from a shell, a CI
secret, or a tool such as fnox. mise does not need to know which provider
populated the environment.

## Proposed composition

### Configuration

Add declarations similar to:

```toml
[bootstrap.secrets]
git_personal_name = {
  env = "GIT_PERSONAL_NAME",
  description = "Personal Git user name",
}
git_personal_email = {
  env = "GIT_PERSONAL_EMAIL",
  description = "Personal Git email",
}
git_work_name = {
  env = "GIT_WORK_NAME",
  description = "Work Git user name",
}
git_work_email = {
  env = "GIT_WORK_EMAIL",
  description = "Work Git email",
}

[dotfiles."~/.config/git/identity-personal"]
source = "templates/git/identity-personal.tmpl"
mode = "template"
permissions = "0600"

[dotfiles."~/.config/git/identity-work"]
source = "templates/git/identity-work.tmpl"
mode = "template"
permissions = "0600"
```

The source files would contain only format structure and function calls:

```ini
[user]
    name = {{ secret(name="git_personal_name") }}
    email = {{ secret(name="git_personal_email") }}
```

The work template uses the two work logical names. The target files remain
regular local files, not symlinks into the repository, and their permissions
are repaired to `0600` on each apply.

### Interactive setup

For the first attended setup, the natural command is:

```sh
mise bootstrap --prompt-secrets --yes --force-dotfiles
```

For identity files only:

```sh
mise dot apply --prompt-secrets --yes
```

If the repository's `install.sh` is intended to perform this attended first
setup, it should add `--prompt-secrets` to its normal developer-mode bootstrap
invocation. CI should not use prompting; it should inject the four variables
from its secret environment if it needs to render these files.

### Presence-aware preservation

The template context documents `read_file()` but not a dedicated
`file_exists()` helper. A trusted template can use a side-effect-free `exec()`
check and read the target only in the existing-file branch:

```jinja
{% set target_exists = exec(command='test -f "$HOME/.config/git/identity-personal" && printf present || printf missing') | trim %}{% if target_exists == "present" %}{{ read_file(path=env.HOME ~ "/.config/git/identity-personal") }}{% else %}[user]
    name = {{ secret(name="git_personal_name") }}
    email = {{ secret(name="git_personal_email") }}
{% endif %}
```

The control tags are intentionally kept on the same line around the existing
file branch so the preserved file is rendered byte-for-byte, without template
whitespace being added. The work template uses its own target and secret names.

This behavior is:

- target missing: evaluate `secret()`, prompt or read environment values, and
  create the file;
- target present: read and reproduce the existing file, without resolving the
  secret inputs; and
- identity rotation: remove the target first, then run apply with
  `--prompt-secrets`, or add an explicit refresh switch to bypass the preserve
  branch.

`exec()` runs whenever the template is rendered, including status and diff, so
this is a trusted-configuration technique rather than a special mise
persistence feature.
### Repeat use

Because prompted values are memory-only, these commands behave differently:

```sh
# Prompts for missing values, then renders the files.
mise dot apply --prompt-secrets

# Works without prompts only when the environment already supplies values.
GIT_PERSONAL_NAME=... GIT_PERSONAL_EMAIL=... \
GIT_WORK_NAME=... GIT_WORK_EMAIL=... mise dot apply

# A provider-backed variant.
fnox exec -- mise bootstrap --yes
```

`mise bootstrap secrets status` can report the logical names, mapped
environment variables, and availability without printing values. `--missing`
can turn an unavailable input into a failing check.

A subtle consequence is that `mise dot status` and `mise dot diff` also need
`--prompt-secrets` or the environment when they render these templates. An
existing target file does not make an unavailable template input unnecessary;
mise must render the desired output to compare it.

## Adversarial review

The presence-aware strategy works, but it changes the identity files from
rendered desired state to local adopted state. The main failure modes are:

### Existing file is present but wrong

`test -f` treats an empty, truncated, stale, or malformed file as present. The
preserve branch then reads it, skips all secret calls, and reports the target as
applied. A manually edited identity also becomes invisible to `mise dot status`.
A stronger check should require a regular, non-empty file and valid
`user.name` and `user.email` entries, or the design should explicitly accept
that any existing file is authoritative.

### Rotation has no normal path

Environment values and `--prompt-secrets` are ignored while the target exists.
Changing an identity requires deleting the target first, or adding a refresh
switch such as `MISE_REFRESH_GIT_IDENTITY=1`. Without documenting this, users
will believe changing a secret provider updates the identity when it does not.

### Prompting still fails in unattended runs

A missing target still calls `secret()`. `--prompt-secrets` requires an
interactive terminal, so a first bootstrap over a non-interactive SSH session,
inside a script, or in CI fails unless the four environment variables are
provided. `mise bootstrap secrets status --missing` reports declarations,
not whether the presence-aware templates currently need them, so it can also
report missing values even when both target files already exist.

### Template execution is not free

The `exec()` existence check runs on every render, including `status` and
`diff`, under the trusted configuration. It depends on the shell, `HOME`, and
the exact target path. A changed `HOME`, a path mismatch, or a future template
formatting edit can produce false missing states or perpetual diffs.

### Whitespace and permissions are easy to regress

When the existing branch calls `read_file()`, the rendered output must be
byte-for-byte identical. Adding a newline around the Tera control tags causes
a perpetual `differs` result. `permissions = "0600"` repairs regular files,
but an unreadable existing file makes `read_file()` fail before mise can
repair it; the recovery path is to fix or remove the target.

### Filesystem races and links

The check and read are separate operations. A file can be replaced between
them. `test -f` also follows symlinks, so the check can classify a symlink to
another regular file as present. Mise replaced a tested symlink with a regular
0600 file during apply, but a pre-existing link can still cause unexpected
content to be adopted. If that matters, reject symlinks explicitly and/or
validate the target before reading it.

### Input-format injection

`secret()` inserts values literally. Newlines, quotes, backslashes, or Git
config comment syntax can create malformed configuration or additional config
entries. The prompt should constrain values to ordinary single-line names and
email addresses, or the implementation needs Git-config-specific escaping and
validation.

A temporary fixture confirmed the intended happy path and the important
negative path: after the first render, removing the environment values still
allowed apply and status to succeed while the target existed; removing the
target made the template require the secret inputs again.


- **Identity data is not normally a secret.** This mechanism treats names and
  email addresses as hidden password-style inputs because that is how mise's
  generic secret prompt works. It is still useful for keeping personal data
  out of the repository, but it may be more ceremony than necessary.
- **Prompting is not persistence by itself.** `--prompt-secrets` does not save
  answers. The presence-aware template above can make the target file the local
  persistence boundary, but then the existing target content becomes
  authoritative.
- **Template values are literal.** A newline, quote, backslash, or Git-config
  comment character can change the resulting file. The simplest safe contract
  is to require one-line, ordinary Git names and email addresses. A future
  implementation could add explicit validation or Git-config-specific
  escaping before rendering.
- **Generated files are authoritative.** Once the templates are added, users
  should stop editing the identity targets directly. Direct edits are
  overwritten by the next successful apply.
- **CI remains non-interactive.** CI must supply the environment values or
  skip the identity-dotfile phase. It should not pass `--prompt-secrets`.

## Verification

Using mise `2026.9.18`, a temporary configuration with the declarations and a
single template was applied with environment values. mise:

- rendered the template successfully;
- wrote a regular target file;
- set the target to `0600`; and
- reported the template as unable to render when a later `status` ran without
  the environment values or `--prompt-secrets`.

That confirms the composition, the presence-aware preservation behavior, and
the fact that the secret values themselves remain memory-only. No repository
files or real identity values were changed during the fixture run.

## Sources

- [mise dotfiles: Templates](https://mise.jdx.dev/dotfiles.html#templates)
- [mise bootstrap: Secret inputs](https://mise.jdx.dev/bootstrap/secrets.html)
- [mise templates](https://mise.jdx.dev/templates.html)
- [mise `v2026.9.18` secret resolver](https://github.com/jdx/mise/blob/v2026.9.18/src/system/secrets.rs)
- [mise `v2026.9.18` dotfiles documentation](https://github.com/jdx/mise/blob/v2026.9.18/docs/dotfiles.md)
- [mise `v2026.9.18` bootstrap secret documentation](https://github.com/jdx/mise/blob/v2026.9.18/docs/bootstrap/secrets.md)
