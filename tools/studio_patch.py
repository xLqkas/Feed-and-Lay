"""Turns `git diff HEAD` of the given files into one Luau snippet for the Studio MCP execute_luau tool.

Studio must hold exactly the HEAD version of each script (check with tools/srchash.luau). Hunks are applied by
line number, bottom-up, so only new lines are sent. New files (not in HEAD) are sent whole. The snippet ends by
printing each script's length and 31-polynomial hash for comparison with `lune run tools/srchash.luau`.

Usage: python tools/studio_patch.py <repo file> ... > out.luau
"""
import json
import re
import subprocess
import sys

project = json.load(open("default.project.json", encoding="utf-8"))


def find_paths(node, path, out):
    for k, v in node.items():
        if k.startswith("$"):
            continue
        if isinstance(v, dict):
            p = v.get("$path")
            if p:
                out[p.replace("\\", "/")] = path + [k]
            find_paths(v, path + [k], out)


mapping = {}
find_paths(project["tree"], [], mapping)


def studio_path(f):
    if f in mapping:
        return mapping[f]
    for p, inst in mapping.items():  # folder mapping, e.g. src/client/Loop
        if f.startswith(p + "/"):
            name = f[len(p) + 1 :]
            name = re.sub(r"\.(server|client)?\.?luau$", "", name).rstrip(".")
            return inst + [name]
    raise SystemExit("no Rojo mapping for " + f)


def lua_list(xs):
    return "{" + ", ".join(json.dumps(x) for x in xs) + "}"


def long(s):
    n = 0
    while "]" + "=" * n + "]" in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


out = [
    "local function find(path, class)",
    "\tlocal o = game",
    "\tfor i, name in path do",
    "\t\tlocal c = o:FindFirstChild(name)",
    "\t\tif not c and i == #path then c = Instance.new(class) c.Name = name c.Parent = o end",
    "\t\to = assert(c, name)",
    "\tend",
    "\treturn o",
    "end",
    "local report = {}",
    "local function patch(path, class, hunks, whole)",
    "\tlocal s = find(path, class)",
    "\tlocal lines = string.split((s.Source:gsub('\\r', '')), '\\n')",
    "\tif whole then lines = string.split(whole, '\\n') end",
    "\tfor i = #hunks, 1, -1 do",
    "\t\tlocal h = hunks[i]",
    "\t\tlocal new = if h[3] == '' and h[4] then {} else string.split(h[3], '\\n')",
    "\t\tfor _ = 1, h[2] do table.remove(lines, h[1]) end",
    "\t\tfor k = #new, 1, -1 do table.insert(lines, h[1], new[k]) end",
    "\tend",
    "\tlocal src = table.concat(lines, '\\n')",
    "\ts.Source = src",
    "\tlocal hash = 0",
    "\tfor i = 1, #src do hash = (hash * 31 + string.byte(src, i)) % 4294967296 end",
    "\ttable.insert(report, table.concat(path, '.') .. ' ' .. #src .. ' ' .. hash)",
    "end",
]

for f in sys.argv[1:]:
    path = studio_path(f)
    cls = "Script" if f.endswith(".server.luau") else "LocalScript" if f.endswith(".client.luau") else "ModuleScript"
    exists = subprocess.run(["git", "cat-file", "-e", "HEAD:" + f], capture_output=True).returncode == 0
    if not exists:
        src = open(f, encoding="utf-8").read().replace("\r", "")
        out.append("patch(%s, %s, {}, %s)" % (lua_list(path), json.dumps(cls), long(src)))
        continue
    diff = subprocess.run(
        ["git", "diff", "-U0", "--no-color", "HEAD", "--", f], capture_output=True, text=True, encoding="utf-8"
    ).stdout.replace("\r", "")
    hunks = []
    cur = None
    for line in diff.split("\n"):
        m = re.match(r"@@ -(\d+)(?:,(\d+))? \+\d+(?:,\d+)? @@", line)
        if m:
            start, count = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
            if count == 0:
                start += 1  # pure insertion goes after line `start`
            cur = [start, count, []]
            hunks.append(cur)
        elif cur is not None and line.startswith("+") and not line.startswith("+++"):
            cur[2].append(line[1:])
    parts = []
    for start, count, new in hunks:
        parts.append("{%d, %d, %s%s}" % (start, count, long("\n".join(new)), ", true" if not new else ""))
    out.append("patch(%s, %s, {%s})" % (lua_list(path), json.dumps(cls), ", ".join(parts)))

out.append("return table.concat(report, '\\n')")
print("\n".join(out))
