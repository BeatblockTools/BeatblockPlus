local bbp = {}

bbp.utils = require("bbp.utils")
bbp.loader = require("bbp.loader")

bbp.mods = setmetatable({}, {
    __index = function(_, k)
        return bbp.loader.mods[k]
    end
})

bbp.config = setmetatable({}, {
    __index = function(_, k)
        return bbp.loader.mods[k].config
    end
})

return bbp
