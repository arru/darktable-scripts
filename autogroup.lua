dt = require "darktable"
table = require "table"

_autogroup_interval_error_margin = 1.25

_debug = false

if _debug then dtd = require "darktable.debug" end

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


local function _find_cutoff (intervals)
  local short_time_bias = 1.5
  local last_interval = intervals[3]
  local cutoff_interval = nil
  local key_group_size = 0
  
  if _debug then  
    print("3:\t"..last_interval)
  end
  
  local interval_growth = 1.0
  local max_growth_factor = 0.0
  --Search for largest growth factor, store away base interval value for growth 
  --as cutoff_interval result
  for g = 4, #intervals do
    local new_interval = intervals[g]
    --Add bias to compensate for lack of precision in small (<6 or so) integers
    interval_growth = new_interval/math.max(_autogroup_short_threshold,last_interval+short_time_bias)
    if new_interval > _autogroup_short_threshold and
      interval_growth > max_growth_factor then
      --New highest growth value found, store and continue
      max_growth_factor = interval_growth
      --Clipping cutoff_interval covers a border case where the key group is the
      --first one above _autogroup_short_threshold, so last_interval may be below
      --rather than equal to it
      cutoff_interval = math.max(last_interval, _autogroup_short_threshold)
      key_group_size = g
    end
    
    if _debug then  
      print(g..":\t"..new_interval.."\t("..interval_growth..")")
    end
    last_interval = new_interval
  end
    
  if key_group_size < 2 then
    cutoff_interval = nil
  end
  
  if _debug then
    print ("Using group size: "..(key_group_size))
  end
  
  return cutoff_interval
end

-------- Main script entry point --------

local function _autogroup_main()
  _autogroup_short_threshold = dt.preferences.read("autogroup","LowerGroupingTime","integer")
  _autogroup_long_threshold  = dt.preferences.read("autogroup","UpperGroupingTime","integer")
  no_groups_fallback =  dt.preferences.read("autogroup","NoGroupsFallback","bool")
  
  local progress_analysis_portion = 0.9
  
  local min_interval = {}
  local image_table = dt.gui.selection()
  local ordered_keys = {}
  
  table.sort(image_table,_image_time_sort)
  
  for k in pairs(image_table) do
    table.insert(ordered_keys, k)
  end
  
  local progress_job = dt.gui.create_job ("Auto-grouping images", true)
  
  local progress_analysis_completed = 0
  local num_images = #ordered_keys
  
  -------- Build group size/interval table --------
  
  for i = 1, #ordered_keys do    
    local group_size = 2
    local max_interval = 0
    while max_interval < _autogroup_long_threshold and (i+group_size-1) <= num_images do
      local t_this = _get_image_time(image_table[ ordered_keys[i+group_size-2] ])
      local t_next = _get_image_time(image_table[ ordered_keys[i+group_size-1] ])
      
      assert(t_next >= t_this, "Images not sorted chronologically")
      
      local interval = t_next - t_this
      max_interval = math.max (interval, max_interval)
      
      if max_interval < _autogroup_long_threshold then
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
  
  -------- Find grouping cutoff value --------
  
  local grouping_interval = nil
  --Algorithm must find at least 3-groups within the selected images, or there will
  --be no way to determine group interval
  if #min_interval >= 3 then
    grouping_interval = _find_cutoff(min_interval)
  end
  
  if grouping_interval == nil then
    if no_groups_fallback then
      grouping_interval = _autogroup_short_threshold
    else
      dt.print("No groups found. Please increase max time apart, select more images or enable guaranteed grouping.")
      
      progress_job.valid = false
      return
    end
  else
    grouping_interval = math.max(math.min(
      math.ceil(grouping_interval * _autogroup_interval_error_margin),
      _autogroup_long_threshold),_autogroup_short_threshold)
  end
  
  if _debug then
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

-------- Error handling wrapper --------

function autogroup_handler()
  if (_debug) then
    --Do a regular call, which will output complete error traceback to console
    _autogroup_main()
  else
    
    local main_success, main_error = pcall(_autogroup_main)
    if (not main_success) then
      --Do two print calls, in case tostring conversion fails, user will still see a message
      dt.print("An error prevented autogroup script from completing")
      dt.print("An error prevented autogroup script from completing: "..tostring(main_error))
    end
  end
end

dt.preferences.register("autogroup", "LowerGroupingTime", "integer", "Autogroup: images always belong in the same group when time apart (seconds) is no more than", "HELP", 4, 0, 10000 )
dt.preferences.register("autogroup", "UpperGroupingTime", "integer", "Autogroup: images will never be grouped if time apart (seconds) is more than", "HELP", 60, 2, 10000 )
dt.preferences.register("autogroup", "NoGroupsFallback", "bool", "Autogroup: guaranteed grouping, use minimum setting for grouping if no groups can be found", "HELP", true )

dt.register_event("shortcut", autogroup_handler, "Auto-group images based on time taken")
