local bbp = {}

bbp.utils = require("bbp.utils")
bbp.loader = require("bbp.loader")

setmetatable(bbp, {
    __index = function(t, k)
        if k == "mods" then
            return t.loader.mods
        end
        return rawget(t, k)
    end
})

return bbp
