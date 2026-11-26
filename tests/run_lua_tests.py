"""Run the mocked suites with Lua 5.1 (requires the optional lupa package)."""
import pathlib
import os
import sys
import tempfile
import zipfile

# Keep the optional test runtime outside the mod's distributed game files.
sys.path.insert(0, str(pathlib.Path(tempfile.gettempdir()) / "latin-king-lua"))
from lupa.lua51 import LuaRuntime

root = pathlib.Path(__file__).resolve().parent.parent
os.chdir(root)
for name in sys.argv[1:] or ["libellusprogress", "casa", "dialogselection", "king"]:
    path = root / "tests" / (name + "_test.lua")
    print("RUN", path.name, flush=True)
    runtime = LuaRuntime()
    # Exercise the real pet limit, attachment, saving, and migration code.
    bundle = root.parent.parent / "data" / "databundles" / "scripts.zip"
    if bundle.exists():
        with zipfile.ZipFile(bundle) as scripts:
            source = scripts.read("scripts/components/petleash.lua").decode("utf-8")
        runtime.globals().package.preload["components/gamepetleash"] = runtime.eval(
            "function(source) return assert(loadstring(source)) end"
        )(source)
        if name == "king":
            with zipfile.ZipFile(bundle) as scripts:
                for module, filename in {
                    "components/gameamphibiouscreature": "components/amphibiouscreature.lua",
                    "gamecommonstates": "stategraphs/commonstates.lua",
                    "gamehoundgraph": "stategraphs/SGhound.lua",
                    "easing": "easing.lua",
                }.items():
                    runtime.globals().package.preload[module] = runtime.eval(
                        "function(source) return assert(loadstring(source)) end"
                    )(scripts.read("scripts/" + filename).decode("utf-8", errors="replace"))
    runtime.execute(path.read_text(encoding="utf-8-sig"))

lua = LuaRuntime()
for path in [root / "modmain.lua", *root.glob("scripts/**/*.lua")]:
    lua.execute("assert(loadstring(...))", path.read_text(encoding="utf-8-sig"))
print("All mod Lua files parse under Lua 5.1.")
