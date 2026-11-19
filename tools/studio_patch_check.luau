-- Dry run of a tools/studio_patch.py snippet in lune: applies it to the HEAD sources (passed as
-- base files: <snippet> <studioPath>=<headFile> ...) and prints the report, to compare with srchash.
local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")
local snippet = fs.readFile(process.args[1])
local sources = {}
for i = 2, #process.args do
    local k, v = string.match(process.args[i], "^(.-)=(.*)$")
    sources[k] = string.gsub(fs.readFile(v), "\r", "")
end
local function node(path)
    return setmetatable({ _path = path }, {
        __index = function(t, k)
            if k == "Source" then
                return sources[t._path] or ""
            elseif k == "FindFirstChild" then
                return function(self, name)
                    return node(self._path == "" and name or self._path .. "." .. name)
                end
            end
            return nil
        end,
        __newindex = function(t, k, v)
            if k == "Source" then
                sources[t._path] = v
            end
        end,
    })
end
local env = { game = node(""), Instance = { new = function() return {} end } }
setmetatable(env, { __index = _G })
local fn = luau.load(snippet, { environment = env })
print(fn())
