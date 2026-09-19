-- No-op install: the extension is not fetched or installed here. Real install
-- happens in scripts/apply-vscode-extensions.sh via `code`. A marker file is
-- written to ctx.install_path so mise's health check (mise doctor) sees a
-- non-empty install directory and does not flag the tool as broken.
--
-- Future: replace the no-op with a real installer, e.g.
--   local cmd = require("cmd")
--   cmd.exec('code --install-extension "' .. ctx.tool .. '" --force')
function PLUGIN:BackendInstall(ctx)
    local marker = io.open(ctx.install_path .. "/.installed", "w")
    if marker then
        marker:write(ctx.tool .. "@" .. ctx.version .. "\n")
        marker:close()
    end
    return {}
end
