dt = require "darktable"

local function _parse_datetime(str)
  local y, m, d, h, mi, s = str:match("(%d%d%d%d):(%d?%d?):(%d?%d?) (%d?%d):(%d%d):(%d%d)$")
  assert (y ~= nil)
  assert (m ~= nil)
  assert (d ~= nil)
  
  return os.time{year=y, month=m, day=d, hour=h, min=mi, sec=s}
end
  

local function collect_by_day()
  local image_table = dt.gui.action_images
  local target_date = nil
  
  for _, image in pairs(image_table) do
    if image.exif_datetime_taken ~= nil then
      target_date = _parse_datetime(image.exif_datetime_taken)
      break
    end
  end
  
  if target_date ~= nil then
    print (target_date)
    local rule = dt.gui.libs.collect.new_rule()
    rule.mode = "DT_LIB_COLLECT_MODE_AND"
    rule.data = os.date("%Y:%m:%d", target_date)
    rule.item = "DT_COLLECTION_PROP_TIME"
    
    dt.print(os.date("%B %d %Y", target_date))
    
    dt.gui.libs.collect.filter({rule})
  else
    dt.print("Image has no date information")
  end
end

dt.register_event("shortcut", collect_by_day, "Open collection with same date as selected image")
