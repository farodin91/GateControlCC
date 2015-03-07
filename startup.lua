local libs = {{"main", "main.lua"},{"ui", "ui.lua"},{"lib", "lib.lua"},}

local user = "farodin91"
local branch = "master"
local repo = "GateControlCC"

local function getFileLink(path)
  return "https://raw.githubusercontent.com/"..user.."/"..repo.."/"..branch.."/"..path
end

for i,v in ipairs(libs) do
  print("Download..."..getFileLink(v[2]))
  local f = http.get(getFileLink(v[2])) 
  local h = fs.open(v[1], "w")
  h.write(f.readAll())
  h.close()
  --shell.run("pastebin","get "..v[2].." "..v[1])
end

shell.run("main")