dt = require "darktable"
table = require "table"

local function isnan(x) return x ~= x end

local function write_geotag()
  local images_to_write = {}
  local image_table = dt.gui.selection();
  local image_table_count = 0
  
  for _,image in pairs(image_table) do
    if (not isnan(image.longitude) and not isnan(image.latitude)) then
      
      
      
      table.insert(images_to_write,image)
      image_table_count = image_table_count + 1
    end
  end
  
  save_job = dt.gui.create_job ("Saving exif geotags", true)
  local image_done_count = 0
  
  for _,image in pairs(images_to_write) do
    local imagePath = "'"..image.path.."/"..image.filename.."'"
    
    local exifCommand = "exiftool"
    if (dt.preferences.read("write_geotag","DeleteOriginal","bool")) then
      exifCommand = exifCommand.." -overwrite_original"
    end
    if (dt.preferences.read("write_geotag","KeepFileDate","bool")) then
      exifCommand = exifCommand.." -preserve"
    end
    exifCommand = exifCommand.." -exif:gpslatitude="..image.latitude.." -exif:gpslongitude="..image.longitude.." "..imagePath
    
    local testIsFileCommand = "test -f "..imagePath
    
    --Will fail and exit if image file does not exist (or path is invalid)
    coroutine.yield("RUN_COMMAND", testIsFileCommand)
    
    
    
    
    coroutine.yield("RUN_COMMAND", exifCommand)
    
    dt.print("Wrote geotag for "..image.filename)
    save_job.percent = image_table_count/image_done_count
    image_done_count = image_done_count + 1
    
    
  end
  
  save_job.valid = false
end

dt.preferences.register("write_geotag", "DeleteOriginal", "bool", "Write geotag: delete original image file", "Delete original image file after updating EXIF. When off, keep it in the same folder, appending _original to its name", false )
dt.preferences.register("write_geotag", "KeepFileDate", "bool", "Write geotag: carry over original image file's creation & modification date", "Sets same creation & modification date as original file when writing EXIF. When off, time and date will be that at time of writing new file, to reflect that it was altered. Camera EXIF date and time code are never altered, regardless of this setting.", true )

dt.register_event("shortcut",write_geotag, "Write geotag to image file")
