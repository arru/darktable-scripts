dt = require "darktable"

local mount_root = "/Volumes"
local dest_root = "/Pictures"
local dir_structure_string = "${year}/${month}/${day}"
local exif_date_pattern = "(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)"

--https://www.darktable.org/usermanual/ch02s03.html.php#supported_file_formats
local supported_image_formats_init = {"3FR", "ARW", "BAY", "BMQ", "CAP", "CINE",
"CR2", "CRW", "CS1", "DC2", "DCR", "DNG", "ERF", "FFF", "EXR", "IA", "IIQ",
"JPEG", "JPG", "K25", "KC2", "KDC", "MDC", "MEF", "MOS", "MRW", "NEF", "NRW",
"ORF", "PEF", "PFM", "PNG", "PXN", "QTK", "RAF", "RAW", "RDC", "RW1", "RW2",
"SR2", "SRF", "SRW", "STI", "TIF", "TIFF", "X3F"}

local supported_image_formats = {}
for index,ext in pairs(supported_image_formats_init) do
  supported_image_formats[ext] = true
end

-------- Support functions --------

local function interp(s, tab)
  return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end
getmetatable("").__mod = interp

local function escape_path(path)
  return string.gsub(path, " ", "\\ ")
end

local function split_path(path)
  return string.match(path, "(.-)([^\\/]-%.?([^%.\\/]*))$")
end

-------- import_transaction class --------

local import_transaction = {
  type = nil,
  srcPath = nil,
  destPath = nil,
  date = nil,
  tags = nil,
  copied = false
}

import_transaction.__index = import_transaction

function import_transaction.new(path)
  local self = setmetatable({}, import_transaction)
  self.srcPath = path
  return self
end

function import_transaction.load(self)
  --check if supported image file or movie, set self.type to 'image' or
  --'movie' or 'none' otherwise
  assert(self.srcPath ~=nil)
  
  local dir, name, ext = split_path(self.srcPath)
  
  if (ext == nil) then
    print (dir.." - "..name.." X")
  else
    print (dir.." - "..name.." - "..ext)
  end
  
  if (ext ~= nil and supported_image_formats[ext:upper()] == true) then
    self.tags = {}
    
    for exifLine in io.popen("exiftool -n -DateTimeOriginal '"..self.srcPath.."'"):lines() do
      local tag, value = string.match(exifLine, "([%a ]-)%s+: (.-)$")
      if (tag ~= nil) then
        --print ("tag:'"..gpsTag.."' val:'"..gpsValue.."'")
        self.tags[tag] = value
      end
    end
    local date = {}    
    date['year'], date['month'], date['day'], date['hour'], date['minute'], date['seconds']
    = self.tags['Time Original']:match(exif_date_pattern)
    self.date = date
    
    self.type = 'image'
    self.destPath = interp(dest_root.."/"..dir_structure_string.."/"..name, self.date)
  end
  --använd sökväg för film om det är en film
end

function import_transaction.copy_image(self)
  assert (self.destPath ~= nil)
  assert (self.tags ~= nil)
  assert (self.date ~= nil)
  assert (self.type == 'image')
  
  local destDir,_,_ = split_path(self.destPath)
  
  local makeDirCommand = "mkdir -p '"..destDir.."'"
  local copyCommand = "cp -n '"..self.srcPath.."' '"..self.destPath.."'"
  
  coroutine.yield("RUN_COMMAND", makeDirCommand)
  
  coroutine.yield("RUN_COMMAND", copyCommand)
  
  self.copied = true
  
  return destDir
end

-------- Main function --------

function copy_import()
  --TODO diagnostik
  local numImagesCopied = 0
  local numImagesDuplicate = 0
  local numUnsupportedFiles = 0

  local testDestRootMounted = "test -d '"..dest_root.."'"
  local destMounted = os.execute(testDestRootMounted)
  
  if (destMounted ~= true) then
    dt.print(dest_root.." is not mounted. Please mount it, then try again.")
    return
  end

  transactions = {}
  changedDirs = {}
  
  for imagePath in io.popen("ls "..escape_path(mount_root).."/*/DCIM/*/*.*"):lines() do
    local trans = import_transaction.new(imagePath)
    table.insert(transactions,trans)
  end
  
  for _,tr in pairs(transactions) do
    tr:load()
    if (tr.type =='image') then
      local destDir = tr:copy_image()
      changedDirs[destDir] = true
    end
  end
  
  for dir,_ in pairs(changedDirs) do
    dt.database.import(dir)
  end
end

dt.register_event("shortcut",copy_import, "Copy and import images from DCF volumes (such as flash memory cards)")