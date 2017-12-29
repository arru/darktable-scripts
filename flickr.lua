dt = require "darktable"

local _debug = false

local exported_flickr_tag = dt.tags.create("darktable|exported|flickr")
local internal_tag_prefix = "darktable|"

local function split_path(path)
    return string.match(path, "(.-)([^\\/]-%.?([^%.\\/]*))$")
end

local scripts_dir, _, _ = split_path(debug.getinfo(1).source:match("@(.*)$"))
local python_uploader_stem = "python "..scripts_dir.."flickr_upload.py "

local function _flickr_storage_main(storage, image_table, extra_data)
    for image, export_file_path in pairs(image_table) do
        local tag_composite = ""
        for _,tag in ipairs(dt.tags.get_tags(image)) do
            if string.sub(tag.name,1,string.len(internal_tag_prefix))~=internal_tag_prefix then
                tag_composite = tag_composite..'"'..tag.name..'" '
            end
        end
        
        local upload_command = python_uploader_stem.."'"..export_file_path.."' '"..image.title.."' '"..image.description.."' '"..tag_composite.."'"
        
        local uploadSuccess = os.execute(upload_command)
        assert(uploadSuccess == true)
        
        image.blue = false
        image.purple = true
        dt.tags.attach(exported_flickr_tag, image)
    end
end

function _flickr_storage_handler(storage, image_table, extra_data)
  if (_debug) then
    --Do a regular call, which will output complete error traceback to console
    _flickr_storage_main(storage, image_table, extra_data)
  else

    local main_success, main_error = pcall(_flickr_storage_main, storage, image_table, extra_data)
    if (not main_success) then
      --Do two print calls, in case tostring conversion fails, user will still see a message
      dt.print("An error prevented Flickr upload script from completing")
      dt.print("An error prevented Flickr upload script from completing: "..tostring(main_error))
    end
  end
end

dt.register_storage("flickr_upload", "Flickr script", nil, _flickr_storage_handler)
