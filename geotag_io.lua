dt = require "darktable"
table = require "table"

local _debug = false
local _geotag_io_dry_run = false
local exiftool_path = "/usr/local/bin/exiftool"

local function debug_print(message)
  if _debug then
    print(message)
  end
end

local nil_geo_tag = dt.tags.create("darktable|geo|nil")

local function getImagePath(i) return "'"..i.path.."/"..i.filename.."'" end

local function read_geotags(image)
  local tags = {}
  local exifReadProcess = io.popen(exiftool_path.." -n "..getImagePath(image))
  local exifLine = exifReadProcess:read()
  while exifLine do
    if (exifLine ~= '') then
      local gpsTag, gpsValue = string.match(exifLine, "(GPS [%a ]-)%s+: (.-)$")
      if (gpsTag ~= nil) then
        tags[gpsTag] = gpsValue
      end 
    end
    exifLine = exifReadProcess:read()
  end
  exifReadProcess:close()
  
  return tags
end

local function _write_geotag()
  local images_to_write = {}
  local image_table = dt.gui.selection()
  local precheck_fraction = 0.2
  local image_table_count = 0
  local tagged_files_skipped = 0
  
  save_job = dt.gui.create_job ("Saving exif geotags", true)
  
  for _,image in pairs(image_table) do
    --Will silently skip if coordinates are nil or 0.0
    if (image.longitude and image.latitude) then
      dt.tags.detach(nil_geo_tag,image)

      local includeImage = true
      if (not dt.preferences.read("geotag_io","OverwriteGeotag","bool")) then
        local tags = read_geotags(image)
        
        --Skip image if it has ANY GPS tag, not just location
        if next(tags) ~= nil then
          includeImage = false 
        end
        
        if (not includeImage) then
          tagged_files_skipped = tagged_files_skipped + 1
        end
      end
      
      if includeImage then
        table.insert(images_to_write,image)
        image_table_count = image_table_count + 1
      end
    end
  end
  
  save_job.percent = precheck_fraction
  
  local image_done_count = 0
  
  for _,image in pairs(images_to_write) do
    local writeExifCommand = exiftool_path
    if (dt.preferences.read("geotag_io","DeleteOriginal","bool")) then
      writeExifCommand = writeExifCommand.." -overwrite_original"
    end
    if (dt.preferences.read("geotag_io","KeepFileDate","bool")) then
      writeExifCommand = writeExifCommand.." -preserve"
    end
    
    local imagePath = getImagePath(image)
    
    local testIsFileSuccess = os.execute("test -f "..imagePath)
    assert(testIsFileSuccess == true)
    
    writeExifCommand = writeExifCommand.." -exif:GPSLatitude="..image.latitude.." -exif:GPSLatitudeRef="..image.latitude.." -exif:GPSLongitude="..image.longitude.." -exif:GPSLongitudeRef="..image.longitude.." -exif:GPSAltitude= -exif:GPSAltitudeRef= -exif:GPSHPositioningError= "..imagePath
    
    if _geotag_io_dry_run == true then
      debug_print (writeExifCommand)
    else
      local writeExifSuccess = os.execute(writeExifCommand)
      assert(writeExifSuccess == true)
    end
    
    image_done_count = image_done_count + 1
    save_job.percent = (image_done_count/image_table_count)*(1-precheck_fraction) + precheck_fraction
  end
  
  save_job.valid = false
  
  if (tagged_files_skipped > 0) then
    dt.print(tagged_files_skipped.." image(s) were skipped as they already had a EXIF geotag")
  end
end

local function _reset_geotag()
  local image_table = dt.gui.selection()
  local processed_count = 0
  local skipped_count = 0
  
  for _,image in pairs(image_table) do
    --read_geotags will fail silently (return empty table) if file was not found
    local tags = read_geotags(image)
    local lat = nil
    local lon = nil
    
    if next(tags) ~= nil then
      if (tags['GPS Latitude'] ~= nil and tags['GPS Longitude'] ~= nil) then
        lat = tonumber(tags['GPS Latitude'])
        lon = tonumber(tags['GPS Longitude'])
      elseif (tags['GPS Position'] ~= nil) then
          lat, lon = string.match(tags['GPS Position'], "([%d%.]+) ([%d%.]+)")
      end
    end
    
    if (lat ~= nil and lon ~= nil) then
      image.latitude = lat
      image.longitude = lon
      processed_count = processed_count + 1
    else
      if (dt.preferences.read("geotag_io","ClearIfEmpty","bool")) then
        image.latitude = nil
        image.longitude = nil
        --Mitigation for bug http://darktable.org/redmine/issues/10450
        dt.tags.attach(nil_geo_tag,image)
      end
      skipped_count = skipped_count + 1
    end
  end
  
  local skipped_verb = "skipped"
  if (dt.preferences.read("geotag_io","ClearIfEmpty","bool")) then
    skipped_verb = "cleared"
  end
  dt.print(processed_count.." image geotags reset ("..skipped_count.." "..skipped_verb..")")
end

-------- Error handling wrappers --------

function write_geotag_handler()
  if (_debug) then
    --Do a regular call, which will output complete error traceback to console
    _write_geotag()
  else
    
    local main_success, main_error = pcall(_write_geotag)
    if (not main_success) then
      --Do two print calls, in case tostring conversion fails, user will still see a message
      dt.print("An error prevented write geotag script from completing")
      dt.print("An error prevented write geotag script from completing: "..tostring(main_error))
    end
  end
end

function reset_geotag_handler()
  if (_debug) then
    --Do a regular call, which will output complete error traceback to console
    _reset_geotag()
  else
    
    local main_success, main_error = pcall(_reset_geotag)
    if (not main_success) then
      --Do two print calls, in case tostring conversion fails, user will still see a message
      dt.print("An error prevented reset geotag script from completing")
      dt.print("An error prevented reset geotag script from completing: "..tostring(main_error))
    end
  end
end


dt.preferences.register("geotag_io", "OverwriteGeotag", "bool", "Write geotag: allow overwriting existing file geotag", "Replace existing geotag in file. If unchecked, files with lat & lon data will be silently skipped.", false )
dt.preferences.register("geotag_io", "DeleteOriginal", "bool", "Write geotag: delete original image file", "Delete original image file after updating EXIF. When off, keep it in the same folder, appending _original to its name", false )
dt.preferences.register("geotag_io", "KeepFileDate", "bool", "Write geotag: carry over original image file's creation & modification date", "Sets same creation & modification date as original file when writing EXIF. When off, time and date will be that at time of writing new file, to reflect that it was altered. Camera EXIF date and time code are never altered, regardless of this setting.", true )
dt.preferences.register("geotag_io", "ClearIfEmpty", "bool", "Reset geotag: if file has no geotag, clear Darktable geotag when resetting.", "Clear Darktable geotag if file about to be reset has no geotag. When off, Darktable geotag will only be altered if geotag exists in file.", true )

dt.register_event("shortcut",write_geotag_handler, "Write geotag to image file")
dt.register_event("shortcut",reset_geotag_handler, "Reset geotag to value in file")
