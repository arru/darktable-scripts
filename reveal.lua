dt = require "darktable"
table = require "table"

local _debug = true

local function debug_print(message)
  if _debug then
    print(message)
  end
end

function file_exists(path)
  local testIsFileCommand = "test -s "..path
  local testIsNotFileCommand = "test ! -s "..path
  
  local positiveTest = os.execute(testIsFileCommand)
  local negativeTest = os.execute(testIsNotFileCommand)
  
  assert(positiveTest ~= negativeTest)
  
  return (positiveTest ~= nil)
end

local function get_image_path(i) return "'"..i.path.."/"..i.filename.."'" end

local function reveal()
  local image_table = dt.gui.selection()
  local missing_image = nil
  
  command_string = "open -R "
  
  for _,image in pairs(image_table) do
    local full_path = get_image_path(image)
    if (file_exists(full_path)) then
      command_string = command_string..full_path.." "
    else
      missing_image = image
    end
  end
  
  if (missing_image == nil) then
    coroutine.yield("RUN_COMMAND", command_string)
  else
    --Show message and reveal parent folder (if available)
    dt.print("Could not find "..get_image_path(missing_image)..", it might be offline or missing.")
    coroutine.yield("RUN_COMMAND", "open '"..missing_image.path.."'")
  end
end

dt.register_event("shortcut",reveal, "Reveal selected image(s) in Finder")
