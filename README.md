Write geotags back to file exif data
====================================

### What it does
Darktable allows you to geotag images using both .gpx track data, or point-and-click. There is no way, however, to write this data into the original image file as EXIF. This script does exactly that, allowing you to rely only on Darktable for geotagging your images in a persistent and reliable way.

### Features
* Writes EXIF geotags as assigned in Darktable to image files

###### Settings for
* Preserving original modification date
* Retaining original image file
* Writing only to files without existing EXIF geotags

### Requirements
* [Exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/)
* Built and tested for Darktable 1.6

### Usage
Put in darktable/lua folder inside darktable's configuration. Add `require "write_geotag"` to luarc file. Relaunch Darktable and locate the new command in Darktable's keyboard shortcut preferences. Set a shortcut you'd like (ctrl-shift-T is a good choice) and you're good to go.

_Although this script has been written with fail safety in mind, the author of this software takes no responsibility for direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption). See license for complete disclaimer. Do your backups!_
