dt = require "darktable"
table = require "table"

local _debug = true

local hugin_install_path = "/Applications/Hugin/Hugin.app/Contents/MacOS/"
local panorama_source_tag = dt.tags.create("darktable|stack|panorama")
local mini_threshold = 3
local points_tool_pano = "cpfind --multirow --celeste"

local function debug_print(message)
  if _debug then
    print(message)
  end
end

local function getImagePath(i) return "'"..i.path.."/"..i.filename.."'" end

local function _create_project(image_table, create_command, tag)
  local previous_image = nil
  for _,image in pairs(image_table) do
    create_command = create_command.." "..getImagePath(image)
    dt.tags.attach(tag, image)
    
    if previous_image ~= nil then
      image.group_with(image, previous_image)
    end
    previous_image = image
  end

  local create_success = os.execute(create_command)
  assert(create_success == true)
end

local function _post_create_actions(output_path)
  local reveal_command = "open -R "
  reveal_command = reveal_command.." '"..output_path.."'"
  coroutine.yield("RUN_COMMAND", reveal_command)

  local hugin_command = hugin_install_path.."hugin "
  hugin_command = hugin_command.." '"..output_path.."' &"
  coroutine.yield("RUN_COMMAND", hugin_command)
end

local function _create_pto(mode)
  local image_table = dt.gui.selection()
  
  local num_images = 0
  local first_image = nil
  for _,i in pairs(image_table) do
    num_images = num_images + 1
    if num_images == 1 then
      first_image = i
    end
  end
  
  if num_images > 1 then
    local pto_final_path = dt.preferences.read("panotools","PTOOutputDirectory","directory")
    
    local pto_name = first_image.filename
    if num_images <= mini_threshold then
      pto_name = pto_name.." M"
    else
      pto_name = pto_name..mode
    end
    
    pto_temp_path = "/tmp/"..pto_name..".pto"
    pto_final_path = pto_final_path.."/"..pto_name..".pto"
    
    local create_command = hugin_install_path.."pto_gen".." -o '"..pto_temp_path.."'"
    
    _create_project(image_table, create_command, panorama_source_tag)

    local points_command = hugin_install_path..points_tool_pano.." -o '"..pto_final_path.."' '"..pto_temp_path.."'"
    --debug_print(points_command)
    coroutine.yield("RUN_COMMAND", points_command)

    _post_create_actions(pto_final_path)
  else
    dt.print("Please select at least 2 images to create panorama project")
  end
end

function create_pto_handler()
  if (_debug) then
    --Do a regular call, which will output complete error traceback to console
    _create_pto('P')
  else
    
    local main_success, main_error = pcall(_create_pto,'P')
    if (not main_success) then
      local error_message = "An error prevented create .pto script from completing"
      --Do two print calls, in case tostring conversion fails, user will still see a message
      dt.print(error_message)
      dt.print(error_message..": "..tostring(main_error))
    end
  end
end

dt.register_event("shortcut", create_pto_handler, "Create new Hugin (.pto) project from selected images")
dt.preferences.register("panotools", "PTOOutputDirectory", "directory", "Panotools: where to put created .pto projects", "", "~/" )
