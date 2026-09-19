-- No environment to export: these are editor extensions, not tools on PATH.
function PLUGIN:BackendExecEnv(ctx)
    return { env_vars = {} }
end
