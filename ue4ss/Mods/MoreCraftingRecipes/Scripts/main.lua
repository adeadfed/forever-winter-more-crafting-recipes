local source = debug.getinfo(1, "S").source:gsub("^@", "")
local mod_folder = assert(source:match("^(.*[\\/])Scripts[\\/][^\\/]+$"), "mod directory unavailable")
require("core/bootstrap").start(mod_folder)
