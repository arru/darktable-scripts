dt = require "darktable"

local exif_date_pattern = "(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)"

--https://www.darktable.org/usermanual/ch02s03.html.php#supported_file_formats
local supported_image_formats_init = {"3FR", "ARW", "BAY", "BMQ", "CAP", "CINE",
"CR2", "CRW", "CS1", "DC2", "DCR", "DNG", "ERF", "FFF", "EXR", "IA", "IIQ",
"JPEG", "JPG", "K25", "KC2", "KDC", "MDC", "MEF", "MOS", "MRW", "NEF", "NRW",
"ORF", "PEF", "PFM", "PNG", "PXN", "QTK", "RAF", "RAW", "RDC", "RW1", "RW2",
"SR2", "SRF", "SRW", "STI", "TIF", "TIFF", "X3F"}

-------- Configuration --------

local mount_root = "/Volumes"

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
  destFileExists = nil
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
  
  
  if (ext ~= nil and supported_image_formats[ext:upper()] == true) then
    self.tags = {}
    
    for exifLine in io.popen("exiftool -n -DateTimeOriginal '"..self.srcPath.."'"):lines() do
      local tag, value = string.match(exifLine, "([%a ]-)%s+: (.-)$")
      if (tag ~= nil) then
        self.tags[tag] = value
      end
    end
    local date = {}    
    date['year'], date['month'], date['day'], date['hour'], date['minute'], date['seconds']
    = self.tags['Time Original']:match(exif_date_pattern)
    self.date = date
    
    self.type = 'image'
    self.destPath = interp(_copy_import_dest_root.."/".._copy_import_dir_structure_string.."/"..name, self.date)
  end
end

function import_transaction.copy_image(self)
  assert (self.destPath ~= nil)
  assert (self.tags ~= nil)
  assert (self.date ~= nil)
  assert (self.type == 'image')
  
  local destDir,_,_ = split_path(self.destPath)
  
  local makeDirCommand = "mkdir -p '"..destDir.."'"
  
  local testIsFileCommand = "test -s '"..self.destPath.."'"
  local testIsNotFileCommand = "test ! -s '"..self.destPath.."'"
  
  local fileExists = os.execute(testIsFileCommand)
  local fileNotExists = os.execute(testIsNotFileCommand)

  assert(fileExists ~= fileNotExists)
  
  if (fileExists == nil) then
    local copyCommand = "cp -n '"..self.srcPath.."' '"..self.destPath.."'"
    
    --print (makeDirCommand)
    coroutine.yield("RUN_COMMAND", makeDirCommand)
    
    --print (copyCommand)
    coroutine.yield("RUN_COMMAND", copyCommand)
  else
    destDir = nil
  end
  
  self.destFileExists = true
  
  return destDir
end

-------- Main function --------

function copy_import()
  local statsNumImagesFound = 0
  local statsNumImagesDuplicate = 0
  local statsNumFilesFound = 0
  local statsNumFilesProcessed = 0
  
  _copy_import_dest_root = dt.preferences.read("copy_import","MainImportDirectory","directory")
  _copy_import_dir_structure_string = dt.preferences.read("copy_import","FolderPattern","directory")
  
  local testDestRootMounted = "test -d '".._copy_import_dest_root.."'"
  local destMounted = os.execute(testDestRootMounted)
  
  if (destMounted ~= true) then
    dt.print(_copy_import_dest_root.." is not mounted. Please mount it, then try again.")
    return
  end

  transactions = {}
  changedDirs = {}
  
  for imagePath in io.popen("ls "..escape_path(mount_root).."/*/DCIM/*/*.*"):lines() do
    local trans = import_transaction.new(imagePath)
    table.insert(transactions,trans)
    statsNumFilesFound = statsNumFilesFound + 1
  end
  
  local copy_progress_job = dt.gui.create_job ("Copying images", true)
    
  for _,tr in pairs(transactions) do
    tr:load()
    if (tr.type =='image') then
      statsNumImagesFound = statsNumImagesFound + 1
      local destDir = tr:copy_image()
      if (destDir ~= nil) then
        changedDirs[destDir] = true
      else
        statsNumImagesDuplicate = statsNumImagesDuplicate + 1
      end
    end
    statsNumFilesProcessed = statsNumFilesProcessed + 1
    copy_progress_job.percent = statsNumFilesProcessed / statsNumFilesFound
  end
  
  copy_progress_job.valid = false
  
  for dir,_ in pairs(changedDirs) do
    dt.database.import(dir)
  end
  
  if (statsNumFilesFound > 0) then
    local completionMessage = ""
    if (statsNumImagesFound > 0) then
      completionMessage = statsNumImagesFound.." images imported."
      if (statsNumImagesDuplicate > 0) then
        completionMessage = completionMessage.." ".." of which "..statsNumImagesDuplicate.." had already been copied."
      end
    end
    if (statsNumFilesFound > statsNumImagesFound) then
      local numFilesIgnored = statsNumImagesFound -statsNumFilesFound
      completionMessage = completionMessage.." "..numFilesIgnored.." unsupported files were ignored."
    end
    dt.print(completionMessage)
  else
    dt.print("No DCF files found. Is your memory card not mounted, or empty?")
  end
end

dt.preferences.register("copy_import", "MainImportDirectory", "directory", "Copy import: root directory to import to (photo library)", "help goes here", "/" )
dt.preferences.register("copy_import", "FolderPattern", "string", "Copy import: directory naming pattern for imports", "help goes here", "${year}/${month}/${day}" )
dt.register_event("shortcut",copy_import, "Copy and import images from DCF volumes (such as flash memory cards)")