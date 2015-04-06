dt = require "darktable"
table = require "table"

_autogroup_debug = false
_autogroup_interval_error_margin = 1.25

if _autogroup_debug then dtd = require "darktable.debug" end

-------- Support functions --------

local function _get_image_time (image)
  local datestring = image.exif_datetime_taken
  local pattern = "(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)"
  
  local xyear, xmonth, xday, xhour, xminute, xseconds = datestring:match(pattern)

  --Bad 0000:00:00 00:00:00 date workaround
  xyear = math.max (xyear, 1970)
  xmonth = math.max (xmonth, 1)
  xday = math.max (xday, 1)
  
  local time = os.time({year = xyear, month = xmonth, day = xday,
  hour = xhour, min = xminute, sec = xseconds})
  assert (time, "Failed parsing datestring '"..datestring.."'")
  
  return time
end

local function _image_time_sort (image_a, image_b)
  local a_time = _get_image_time(image_a)
  local b_time = _get_image_time(image_b)
  
  return a_time < b_time
end

-------- Main script entry point --------

local function autogroup()
  local short_threshold = dt.preferences.read("autogroup","LowerGroupingTime","integer")
  local long_threshold  = dt.preferences.read("autogroup","UpperGroupingTime","integer")
  
  local min_interval = {}
  
  local image_table = dt.gui.selection()
  
  
  local ordered_keys = {}
  local progress_analysis_portion = 0.9
  
  table.sort(image_table,_image_time_sort)
  
  for k in pairs(image_table) do
    table.insert(ordered_keys, k)
  end
  
  progress_job = dt.gui.create_job ("Auto-grouping images", true)
  
  local progress_analysis_completed = 0
  local num_images = #ordered_keys
  
  -------- Build group size/interval table --------
  
  for i = 1, #ordered_keys do    
    local group_size = 2
    local max_interval = 0
    while max_interval < long_threshold and (i+group_size-1) <= num_images do
      local t_this = _get_image_time(image_table[ ordered_keys[i+group_size-2] ])
      local t_next = _get_image_time(image_table[ ordered_keys[i+group_size-1] ])
      
      assert(t_next >= t_this, "Images not sorted chronologically")
      
      local interval = t_next - t_this
      max_interval = math.max (interval, max_interval)
      
      if max_interval < long_threshold then
        if min_interval [group_size] == nil then
          --Insert initial value into min_interval if empty
          min_interval [group_size] = max_interval
        else
          min_interval [group_size] = math.min (max_interval, min_interval [group_size])
        end
      end
      
      group_size = group_size + 1
    end
    
    progress_analysis_completed = progress_analysis_completed + 1
    progress_job.percent = (progress_analysis_completed/num_images)
    *progress_analysis_portion
  end
  
  -------- Debug and error checking of interval table --------
  
  --Algorithm must find at least 3-groups within the selected images, or there will
  --be no way to determine group interval
  if #min_interval < 3 then
    dt.print("No groups found. Please increase max time apart, or select more images.")
    
    progress_job.valid = false
    return
  end
  
  -------- Find grouping cutoff value --------
  
  local short_time_bias = 1.5
  local last_interval = min_interval[3]
  local grouping_interval = nil
  local key_group_size = 0
  
  local interval_growth = 1.0
  local max_growth_factor = 0.0
  --Search for largest growth factor, store away base interval value for growth 
  --as grouping_interval result
  for g = 4, #min_interval do
    local new_interval = min_interval[g]
    --Add bias to compensate for lack of precision in small (<6 or so) integers
    interval_growth = new_interval/math.max(short_threshold,last_interval+short_time_bias)
    if last_interval > short_threshold and interval_growth > max_growth_factor then
      --New highest growth value found, store and continue
      max_growth_factor = interval_growth
      grouping_interval = last_interval
      key_group_size = g
    end
    
    if _autogroup_debug then  
      print(g..":\t"..new_interval.."\t("..interval_growth..")")
    end
    last_interval = new_interval
  end
  
  if key_group_size < 2 then
    dt.print("Failed to isolate groups. Try selecting more images or decrease grouping factor.")
    
    progress_job.valid = false
    return
  end
  
  grouping_interval = math.min(
    math.ceil(grouping_interval * _autogroup_interval_error_margin), long_threshold)
  
  if _autogroup_debug then
    print ("Using group size: "..(key_group_size))
    print ("Grouping_interval: "..grouping_interval.." s")
  end
  
  -------- Group images by interval obtained above --------
  
  local previous_image = image_table[ ordered_keys[1] ]
  local previous_image_time = _get_image_time(previous_image)
  for i = 2, #ordered_keys do
    local this_image = image_table[ ordered_keys[i] ]
    local this_image_time = _get_image_time(this_image)
    
    local interval = this_image_time - previous_image_time
    if interval <= grouping_interval then
      this_image.group_with(this_image, previous_image)
    end
    previous_image = this_image
    previous_image_time = this_image_time
    
    progress_grouping_completed = progress_analysis_completed + 1
    progress_job.percent = (progress_grouping_completed/num_images) * (1-progress_analysis_portion) + progress_analysis_portion
  end
  
  progress_job.valid = false
end

dt.preferences.register("autogroup", "LowerGroupingTime", "integer", "Autogroup: images always belong in the same group when time apart (seconds) is no more than", "HELP", 2, 0, 10000 )
dt.preferences.register("autogroup", "UpperGroupingTime", "integer", "Autogroup: images will never be grouped if time apart (seconds) is more than", "HELP", 20, 2, 10000 )

dt.register_event("shortcut", autogroup, "Auto-group images based on time taken")
