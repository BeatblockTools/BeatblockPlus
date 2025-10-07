local bbp = {}

bbp.utils = require("bbp.utils")
bbp.loader = require("bbp.loader")

bbp.mods = setmetatable({}, {
    __index = bbp.loader.mods
})

bbp.config = setmetatable({}, {
    __index = function(t, k)
        return t.loader.mods[k].config
    end
})

return bbp
