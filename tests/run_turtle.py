"""Run Lua regression tests with Lupa: python -m pip install lupa."""
from pathlib import Path
import json
import sys
import re

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
for role in ("turtle", "receiver", "router", "controller"):
    entries = [entry for entry in manifest["files"] if role in entry["roles"]]
    assert len({entry["target"] for entry in entries}) == len(entries)
    assert any(entry["target"] == "update.lua" for entry in entries)
    installed = {entry["target"][:-4] for entry in entries}
    for entry in entries:
        source = (root / "turtle" / entry["source"]).read_text(encoding="utf-8")
        for dependency in re.findall(r'require\("([\w_]+)"\)', source):
            assert dependency in installed, f"{role}: {entry['target']} needs {dependency}.lua"
for entry in manifest["files"]:
    assert (root / "turtle" / entry["source"]).is_file()
assert {entry["source"] for entry in manifest["files"]} == {p.name for p in (root / "turtle").glob("*.lua")}
print(f"Syntax OK: {len(files)} Lua files; manifest OK for all 4 roles.", flush=True)
lua.globals().ROOT = root.as_posix()
lua.execute((root / "tests" / "turtle_spec.lua").read_text(encoding="utf-8"))
from fleet_network import run as run_network
run_network(root, LuaRuntime)
run_network(root, LuaRuntime, "floor")
run_network(root, LuaRuntime, "ceiling")
run_network(root, LuaRuntime, "walls", worker_count=3)
run_network(root, LuaRuntime, "walls", corners=True)
run_network(root, LuaRuntime, "walls", worker_count=3, recovery=True)
run_network(root, LuaRuntime, "walls", restock=True)
run_network(root, LuaRuntime, "walls", interior=True, restock=True)
run_network(root, LuaRuntime, "walls", worker_count=3, interior="above", restock=True)
run_network(root, LuaRuntime, "walls", interior="below", restock=True)
run_network(root, LuaRuntime, mixed=True)
run_network(root, LuaRuntime, "quarry", shaft=True)
run_network(root, LuaRuntime, "quarry", shaft=True, worker_count=3)
run_network(root, LuaRuntime, "quarry", shaft_down=True, worker_count=3)
run_network(root, LuaRuntime, "quarry", shaft_down=True, worker_count=6)
from traffic_network import run as run_traffic
run_traffic(root, LuaRuntime)
