dt = require "darktable"

local _debug = true

-------- Constants --------

--TODO return extension = nil if no extension
local function split_path(path)
  return string.match(path, "(.-)([^\\/]-)%.?([^%.\\/]*)$")
end

local function _print_summary(count, verb)
  assert (count >= 0)
  
  if count == 0 then
    dt.print("No images affected")
  elseif count == 1 then
    dt.print("One "..verb)
  else
    dt.print(count.." "..verb)
  end
end

-------- CameraImageTuple class --------

local CameraImageTuple = {
  identifier = nil
}

CameraImageTuple.__index = CameraImageTuple

function CameraImageTuple.new(image)
  local self = setmetatable({}, CameraImageTuple)
  
  self.images = {}
  table.insert(self.images, image)
  
  local _, name, _ = split_path(image.filename)
  
  -- film-based identification
  self.identifier = name..image.film.id

  return self
end

function CameraImageTuple.listRaws(self)
  local raw_list = {}
  for _, image in pairs(self.images) do
    if image.is_raw then
      table.insert(raw_list, image)
    end
  end
  
  return raw_list
end

function CameraImageTuple.listLossies(self)
  local lossy_list = {}
  for _, image in pairs(self.images) do
    if not image.is_raw then
      table.insert(lossy_list, image)
    end
  end
  
  return lossy_list
end

function CameraImageTuple.combine_with(self, tuple)
  assert (tuple.identifier == self.identifier)
  assert (#self.images <= 3 )
  local image_count = #self.images

  
  for _, n in pairs(tuple.images) do
    for _, i in pairs(self.images) do
      if i == n then
        n = nil
      end
    end
    
    if n ~= nil then
      table.insert(self.images, n)
    end
  end
  
  assert (#self.images + #tuple.images > image_count)
end

function CameraImageTuple.rating(self)
  local max_rating = 0
  
  for _, image in pairs(self.images) do
    max_rating = math.max(max_rating, image.rating)
  end
  
  return max_rating
end

-------- Utility functions --------

function _collect_tuples(action_images)
  local all_tuples = {}
  
  for _, image in pairs(action_images) do
    local new_tuple = CameraImageTuple.new(image)
    assert (new_tuple ~= nil)
    local tuple = all_tuples[new_tuple.identifier]
    if tuple == nil then
      all_tuples[new_tuple.identifier] = new_tuple
      tuple = new_tuple
    else
      assert (new_tuple ~= nil)
      assert (new_tuple.identifier ~= nil)
      tuple:combine_with(new_tuple)
    end
    
    -- Needed for film-based pair detection
    for i=1, #image.film do
      local sibling_i = image.film[i]
      local sibling = CameraImageTuple.new(sibling_i)
      
      if sibling.identifier == tuple.identifier then
        tuple:combine_with(sibling)
      end
    end
  end
  
  -- Only keep "true" tuples (having more than one image)
  local filtered_tuples = {}
  for _, t in pairs(all_tuples) do
    if #t.images > 1 then
      --TODO group tuple images
      table.insert(filtered_tuples, t)
    end
  end
  
  return filtered_tuples
end

function _keep(image)
  if image.rating < 0 then
    image.rating = 0
  end
end

function _raw_delete_delete_raw(tuple)
  for _, image in pairs(tuple:listLossies()) do
    _keep(image)
  end
  
  for _, image in pairs(tuple:listRaws()) do
    --reject
    image.rating = -1
  end
end

function _raw_delete_delete_lossy(tuple)
  for _, image in pairs(tuple:listRaws()) do
    _keep(image)
  end
  
  for _, image in pairs(tuple:listLossies()) do
    --reject
    image.rating = -1
  end
end

-------- Action functions --------

-- TODO: support iOS image copies from social media (if doable)
--FIXME: ensure that the "kept" image does not have rejected rating

function raw_delete_delete_by_rating_action()
  local tuples = _collect_tuples(dt.gui.action_images)
  local minRatingForRaw = tonumber(raw_delete_min_rating_combo.value)
  
  raw_delete_counter = 0
  lossy_delete_counter = 0
  
  for _, tuple in pairs(tuples) do
    local rating = tuple:rating()
    
    if rating >= minRatingForRaw then
      _raw_delete_delete_lossy(tuple)
      lossy_delete_counter = lossy_delete_counter + 1
    elseif rating > 0 then
      _raw_delete_delete_raw(tuple)
      raw_delete_counter = raw_delete_counter + 1
    end
  end
  
  dt.print("Deleted "..lossy_delete_counter.." lossy images, "..raw_delete_counter.." raw images")
end

function raw_delete_delete_raw_action()
  local tuples = _collect_tuples(dt.gui.action_images)
  local counter = 0
  
  for _, tuple in pairs(tuples) do
    _raw_delete_delete_raw(tuple)
    counter = counter + 1
  end
  
  _print_summary(counter, "raw image(s) rejected")
end

function raw_delete_delete_lossy_action()
  local tuples = _collect_tuples(dt.gui.action_images)
  local counter = 0

  for _, tuple in pairs(tuples) do
    _raw_delete_delete_lossy(tuple)
    counter = counter + 1
  end
  
  _print_summary(counter, "lossy image(s) rejected")
end

-------- Plugin preferences --------

dt.preferences.register("raw_delete", "DeleteImages", "bool", "Raw delete: delete images instead of rejecting", "", false )

dt.preferences.register("raw_delete", "FindPairsMode", "enum", "Raw delete: pair finding mode", "How to find images in a pair: among selected images only, or in same film rolls as each image", "Selection", "Selection", "Film roll" )

-------- Plugin registration --------

dt.register_event("shortcut", function() raw_delete_delete_raw_action() end, "Keep lossy (eg. JPEG) from pairs of same image")

dt.register_event("shortcut", function() raw_delete_delete_by_rating_action() end, "Keep lossless (eg. RAW) at or above set rating, lossy (eg. JPEG) if lower")

dt.register_event("shortcut", function() raw_delete_delete_lossy_action() end, "Keep lossless (eg. RAW) from pairs of same image")

local delete_raw_button = dt.new_widget("button") {
  label = 'Keep JPG',
  clicked_callback = function(widget)
    raw_delete_delete_raw_action()
  end
}

local delete_lossy_button = dt.new_widget("button") {
  label = 'Keep RAW',
    clicked_callback = function(widget)
    raw_delete_delete_lossy_action()
  end
}

raw_delete_delete_by_rating_button = dt.new_widget("button") {
  label = 'Keep RAW if rating',
  sensitive = true,
  clicked_callback = function(widget)
    raw_delete_delete_by_rating_action()
  end
}

raw_delete_min_rating_combo = dt.new_widget('combobox') {
  label = "≥",
  tooltip = "Keep raw version of images with this rating or higher",
  selected = 4,
  changed_callback = nil,
  reset_callback = function(self)
    self.value = 4
  end,
  1,2,3,4,5
}

dt.register_lib(
  "raw_delete", -- id
  "RAW/JPEG delete", -- name
  true, --expandable
  false, --resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 20}}, --containers
  dt.new_widget("box") {
    orientation = "horizontal",
    delete_raw_button,
    dt.new_widget("box") {
      raw_delete_delete_by_rating_button,
      raw_delete_min_rating_combo
    },
    delete_lossy_button
  },
  nil,-- view_enter
  nil -- view_leave
)
