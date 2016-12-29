dt = require "darktable"
table = require "table"

local _debug = false

local hugin_install_path = "/Applications/Hugin/Hugin.app/Contents/MacOS/"
local panorama_source_tag = dt.tags.create("darktable|stack|panorama")
local hdr_source_tag = dt.tags.create("darktable|stack|hdr")
local mini_threshold = 3

local function debug_print(message)
  if _debug then
    print(message)
  end
end

local function getImagePath(i) return "'"..i.path.."/"..i.filename.."'" end

local function _post_create_actions(output_path)
  local reveal_command = "open -R "
  reveal_command = reveal_command.." '"..output_path.."'"
  os.execute(reveal_command)

  local hugin_command = hugin_install_path.."hugin "
  hugin_command = hugin_command.." '"..output_path.."' &"
  os.execute(hugin_command)
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
    local tag = nil
    local name_suffix = mode
    if mode == 'P' or mode == '3' then
      if num_images <= mini_threshold then
        name_suffix = "M"
      end
      tag = panorama_source_tag
    else
      tag = hdr_source_tag
    end
    pto_name = pto_name.." "..name_suffix
    
    pto_temp_path = "/tmp/"..pto_name..".pto"
    pto_final_path = pto_final_path.."/"..pto_name..".pto"
    
    local create_command = hugin_install_path
    
    if mode == 'H' then
      create_command = create_command.."align_image_stack -p '"..pto_final_path.."'"
    else
      create_command = create_command.."pto_gen -p "
      if mode == '3' then
        --projection type 3: full-frame fisheye
        create_command = create_command.."3"
      else
        assert(mode == 'P')
        --projection type 0: rectilinear
        create_command = create_command.."0"
      end
      create_command = create_command.." -o '"..pto_temp_path.."'"
    end

    local previous_image = nil
    for _,image in pairs(image_table) do
      create_command = create_command.." "..getImagePath(image)
      dt.tags.attach(tag, image)
      
      if previous_image ~= nil then
        image.group_with(image, previous_image)
      end
      previous_image = image
    end
    dt.print(".pto file creation has begun. Hugin will open when alignment is done.")
    
    local create_success = os.execute(create_command)
    assert(create_success == true)

    if mode == 'P' or mode == '3' then
      local findPointsCommand = hugin_install_path.."cpfind --multirow --celeste -o '"..pto_final_path.."' '"..pto_temp_path.."'"
      --debug_print(findPointsCommand)
      
      local findPointsSuccess = os.execute(findPointsCommand)
      assert(findPointsSuccess == true)
    end

    _post_create_actions(pto_final_path)
  else
    dt.print("Please select at least 2 images to create panorama project")
  end
end

function create_hdr_handler()
  if (_debug) then
    --Do a regular call, which will output complete error traceback to console
    _create_pto('H')
  else
    
    local main_success, main_error = pcall(_create_pto,'H')
    if (not main_success) then
      local error_message = "An error prevented create .pto script from completing"
      --Do two print calls, in case tostring conversion fails, user will still see a message
      dt.print(error_message)
      dt.print(error_message..": "..tostring(main_error))
    end
  end
end

function create_panorama_handler()
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

function create_fisheye_pano_handler()
  if (_debug) then
    --Do a regular call, which will output complete error traceback to console
    _create_pto('3')
  else
    
    local main_success, main_error = pcall(_create_pto,'3')
    if (not main_success) then
      local error_message = "An error prevented create .pto script from completing"
      --Do two print calls, in case tostring conversion fails, user will still see a message
      dt.print(error_message)
      dt.print(error_message..": "..tostring(main_error))
    end
  end
end

dt.register_event("shortcut", create_panorama_handler, "Create panorama (Hugin .pto) project from rectilinear images")
dt.register_event("shortcut", create_fisheye_pano_handler, "Create panorama (Hugin .pto) project from full-frame fisheye images")
dt.register_event("shortcut", create_hdr_handler, "Create HDR (Hugin .pto) project from selected images")
dt.preferences.register("panotools", "PTOOutputDirectory", "directory", "Panotools: where to put created .pto projects", "", "~/" )
