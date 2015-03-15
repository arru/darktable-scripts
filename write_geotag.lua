dt = require "darktable"
table = require "table"

local function isnan(x) return x ~= x end

local function write_geotag()
  local images_to_write = {}
  local image_table = dt.gui.selection();
  
  for _,image in pairs(image_table) do
    if (not isnan(image.longitude) and not isnan(image.latitude)) then      
      table.insert(images_to_write,image)
    end
  end
  
  for _,image in pairs(images_to_write) do
    local imagePath = "'"..image.path.."/"..image.filename.."'"
    local exifCommand = "exiftool -exif:gpslatitude="..image.latitude.." -exif:gpslongitude="..image.longitude.." "..imagePath
    local testIsFileCommand = "test -f "..imagePath
    
    --Will fail and exit if image file does not exist (or path is invalid)
    coroutine.yield("RUN_COMMAND", testIsFileCommand)
    
    coroutine.yield("RUN_COMMAND", exifCommand)
    
    dt.print("Wrote geotag for "..image.filename)
    
  end
end

dt.register_event("shortcut",write_geotag, "Write geotag to image file")
