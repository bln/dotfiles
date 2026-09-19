-- Extensions have no queryable version list here; the marketplace always
-- resolves "latest". Returning a single "latest" lets `= "latest"` in [tools]
-- resolve without hitting any API.
function PLUGIN:BackendListVersions(ctx)
    return { versions = { "latest" } }
end
