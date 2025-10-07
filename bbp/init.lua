local bbp = {}

bbp.utils = require("bbp.utils")
bbp.loader = require("bbp.loader")

bbp.config = setmetatable({}, {
    __index = function(_, k)
        return bbp.loader.mods[k].config
    end,
    -- this doesn't work, thanks lua 😊
    __len = function(_)
        return #bbp.loader.mods
    end
})

-- do this because the __len metamethod doesn't work in lua 5.1
return setmetatable({}, {
    __index = function(_, k)
        if k == "mods" then
            return bbp.loader.mods
        end
        return bbp[k]
    end,
    __newindex = function (_, _, _)
        error("Cannot set members of 'bbp'")
    end
})
