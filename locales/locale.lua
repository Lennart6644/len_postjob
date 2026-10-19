Locales = Locales or {}

function L(key, ...)
    local primary = Locales[Config.Locale] or {}
    local fallback = Locales[Config.FallbackLocale] or {}
    local text = primary[key] or fallback[key] or key
    if select('#', ...) > 0 then
        return text:format(...)
    end
    return text
end

function UIStrings()
    local out = {}
    local fallback = Locales[Config.FallbackLocale] or {}
    local primary = Locales[Config.Locale] or {}
    for key, value in pairs(fallback) do
        if key:sub(1, 3) == 'ui.' then out[key] = value end
    end
    for key, value in pairs(primary) do
        if key:sub(1, 3) == 'ui.' then out[key] = value end
    end
    return out
end
