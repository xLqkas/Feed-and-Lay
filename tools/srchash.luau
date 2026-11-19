-- Prints length and a 31-polynomial hash (CR stripped) of each source file given, matching the check run in
-- Studio (docs/ai/client-v3-notes.md "How code reaches Studio"). Run: lune run tools/srchash.luau <files...>
local fs = require("@lune/fs")
local process = require("@lune/process")
for _, path in process.args do
    local s = string.gsub(fs.readFile(path), "\r", "")
    local h = 0
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i)) % 4294967296
    end
    print(string.format("%s %d %d", path, #s, h))
end
