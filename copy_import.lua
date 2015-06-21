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
local alternate_inbox_name = "Inbox"
local alternate_dests = {
  --nil = using the preference setting for folder structure
  --{"/Users/ThePhotographer/Pictures/Darktable", nil},
  
  --folder structure setting overridden for this destination:
  --{"/Users/ThePhotographer/Pictures/Darktable specials", "${year}/${month}"},
}

local using_multiple_dests = (#alternate_dests > 0)

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

local function on_same_volume(absPathA, absPathB)
  local mountedVolumePattern = "^"..mount_root.."/(.-)/"
  
  local rootA = string.match(absPathA, mountedVolumePattern)
  if (rootA == nil) then
    rootA = absPathA:sub(1,1)
    assert(rootA == "/")
  end
  
  local rootB = string.match(absPathB, mountedVolumePattern)
  if (rootB == nil) then
    rootB = absPathB:sub(1,1)
    assert(rootB == "/")
  end
  
  local isSameVolume = (rootA == rootB)
  return isSameVolume
end

-------- import_transaction class --------

local import_transaction = {
  type = nil,
  srcPath = nil,
  destRoot = nil,
  destStructure = nil,
  destPath = nil,
  date = nil,
  tags = nil,
  destFileExists = nil
}

import_transaction.__index = import_transaction

function import_transaction.new(path, destRoot)
  local self = setmetatable({}, import_transaction)
  self.srcPath = path
  self.destRoot = destRoot
  return self
end

function import_transaction.load(self)
  --check if supported image file or movie, set self.type to 'image' or
  --'movie' or 'none' otherwise
  assert(self.srcPath ~=nil)
  assert(self.destRoot ~= nil)
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
    
    local dirStructure = _copy_import_default_folder_structure
    if (self.destStructure ~= nil) then
      dirStructure = self.destStructure
    end
    self.type = 'image'
    self.destPath = interp(self.destRoot.."/"..dirStructure.."/"..name, self.date)
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
    local copyMoveCommand = "cp -n '"..self.srcPath.."' '"..self.destPath.."'"
    if (on_same_volume(self.srcPath,self.destPath)) then
      copyMoveCommand = "mv -n '"..self.srcPath.."' '"..self.destPath.."'"
    end
    
    --print (makeDirCommand)
    coroutine.yield("RUN_COMMAND", makeDirCommand)
    
    --print (copyCommand)
    coroutine.yield("RUN_COMMAND", copyMoveCommand)
  else
    destDir = nil
  end
  
  self.destFileExists = true
  
  return destDir
end


-------- Subroutines --------

local function scrape_files(scrapeRoot, destRoot, structure, list)
  local numFilesFound = 0
  for imagePath in io.popen("ls "..scrapeRoot.."/*.*"):lines() do
    local trans = import_transaction.new(imagePath, destRoot)
    --Preference value will be used if nil
    trans.destStructure = structure
    
    table.insert(list, trans)
    numFilesFound = numFilesFound + 1
  end
  
  return numFilesFound
end

-------- Main function --------

function copy_import()
  local statsNumImagesFound = 0
  local statsNumImagesDuplicate = 0
  local statsNumFilesFound = 0
  local statsNumFilesProcessed = 0
  
  if(using_multiple_dests) then
    local dcimDestRoot = dt.preferences.read("copy_import","DCFImportDirectorySelect","enum")
  else
    local dcimDestRoot = dt.preferences.read("copy_import","DCFImportDirectoryBrowse","directory")
  end
  _copy_import_default_folder_structure = dt.preferences.read("copy_import","FolderPattern", "string")
  
  transactions = {}
  changedDirs = {}
  
  local testDestRootMounted = "test -d '"..dcimDestRoot.."'"
  local destMounted = os.execute(testDestRootMounted)
  
  if (destMounted == true) then
    statsNumFilesFound = statsNumFilesFound +
      scrape_files(escape_path(mount_root).."/*/DCIM/*", dcimDestRoot, nil, transactions)
  else
    dt.print(dcimDestRoot.." is not mounted. Will only import from inboxes.")
  end
  
  for _, altConf in pairs(alternate_dests) do
    local dir = altConf[1]
    local dirStructure = altConf[2]
    
    local testAltDirExists = "test -d '"..dir.."'"
    local altDirExists = os.execute(testAltDirExists)
    if (altDirExists == true) then
      local ensureInboxExistsCommand = "mkdir -p '"..dir.."/"..alternate_inbox_name.."'"
      coroutine.yield("RUN_COMMAND", ensureInboxExistsCommand)
      
      statsNumFilesFound = statsNumFilesFound +
        scrape_files(escape_path(dir).."/"..escape_path(alternate_inbox_name), dir, dirStructure, transactions)
    else
      dt.print(dir.." could not be found and was skipped over.")
    end
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
      local numFilesIgnored = statsNumFilesFound - statsNumImagesFound
      completionMessage = completionMessage.." "..numFilesIgnored.." unsupported files were ignored."
    end
    dt.print(completionMessage)
  else
    dt.print("No DCF files found. Is your memory card not mounted, or empty?")
  end
end

-------- Darktable registration --------

local alternate_dests_paths = {}
for _,conf in pairs(alternate_dests) do
  table.insert(alternate_dests_paths, conf[1])
end

dt.preferences.register("copy_import", "FolderPattern", "string", "Copy import: default directory naming structure for imports", "Create a folder structure within the import destination folder. Available variables: ${year}, ${month}, ${day}. Original filename is appended at the end.", "${year}/${month}/${day}" )
if(using_multiple_dests) then
  dt.preferences.register("copy_import", "DCFImportDirectorySelect", "enum", "Copy import: which of the destination directories to import mounted flash memories (DCF) to", "Select which folder (from your own multi-import list) that will be used for importing directly from mounted camera flash storage.", alternate_dests_paths[1], unpack(alternate_dests_paths) )
else
  dt.preferences.register("copy_import", "DCFImportDirectoryBrowse", "directory", "Copy import: root directory to import to (photo library)", "Choose the folder that will be used for importing directly from mounted camera flash storage.", "/" )
end
dt.register_event("shortcut",copy_import, "Copy and import images from memory cards and '"..alternate_inbox_name.."' folders")