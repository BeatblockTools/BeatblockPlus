local bbp = {}

bbp.utils = require("bbp.utils")
bbp.loader = require("bbp.loader")

local isLua51 = rawlen == nil
if not isLua51 then
    bbp.mods = setmetatable({}, {
        __index = function(_, k)
            return bbp.loader.mods[k]
        end,
        __len = function(_)
            return #bbp.loader.mods
        end,
        __pairs = function(_)
            return pairs(bbp.loader.mods)
        end,
        __ipairs = function(_)
            return ipairs(bbp.loader.mods)
        end
    })
end

bbp.config = setmetatable({}, {
    __index = function(_, k)
        return bbp.loader.mods[k].config
    end,
    -- this doesn't work, thanks lua 😊
    __len = function(_)
        return #bbp.loader.mods
    end
})

return setmetatable({}, {
    __index = function(_, k)
        -- do this because the __len metamethod doesn't work in lua 5.1
        if isLua51 and k == "mods" then
            return bbp.loader.mods
        end
        return bbp[k]
    end,
    __newindex = function (_, _, _)
        error("Cannot set members of 'bbp'")
    end
})
