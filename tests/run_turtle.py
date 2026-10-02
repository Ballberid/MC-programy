"""Run Lua regression tests with Lupa: python -m pip install lupa."""
from pathlib import Path
import json
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / ".dev-runtime"))
from lupa.lua52 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(text, name) local f, err = load(text, "@" .. name, "t", {}); return f ~= nil, err end')
files = list((root / "turtle").glob("*.lua")) + [root / "dw_update.lua"]
for path in files:
    ok, error = compile_lua(path.read_text(encoding="utf-8"), path.name)
    if not ok:
        raise RuntimeError(error)
manifest = json.loads((root / "turtle" / "manifest.json").read_text(encoding="utf-8"))
for role in ("turtle", "receiver", "router"):
    entries = [entry for entry in manifest["files"] if role in entry["roles"]]
    assert len({entry["target"] for entry in entries}) == len(entries)
    assert any(entry["target"] == "update.lua" for entry in entries)
for entry in manifest["files"]:
    assert (root / "turtle" / entry["source"]).is_file()
assert {entry["source"] for entry in manifest["files"]} == {p.name for p in (root / "turtle").glob("*.lua")}
print(f"Syntax OK: {len(files)} Lua files; manifest OK for all 3 roles.", flush=True)
lua.globals().ROOT = root.as_posix()
lua.execute((root / "tests" / "turtle_spec.lua").read_text(encoding="utf-8"))
