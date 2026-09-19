-- No-op mise backend plugin: makes `vscode-ext:<extension-id>` legal under
-- [tools] so VS Code extensions are declared as first-class machine state in
-- config.toml. This plugin installs nothing; the actual install/upgrade/prune
-- logic lives in scripts/apply-vscode-extensions.sh, driven by `code`.
--
-- Future: BackendInstall (hooks/backend_install.lua) can be grown into a real
-- installer that calls `code --install-extension`, turning this into a
-- functioning backend without changing how extensions are declared.
PLUGIN = {
    name = "vscode-ext",
    version = "0.1.0",
    description = "No-op backend for declaring VS Code extensions in [tools]",
}
