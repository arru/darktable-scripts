Write geotags back to file exif data
====================================

### What it does
Darktable allows you to geotag images using both .gpx track data, or point-and-click. There is no way, however, to write this data into the original image file as EXIF. This script does exactly that, allowing you to rely only on Darktable for geotagging your images in a persistent and reliable way.

### Usage
Put in darktable/lua folder inside darktable's configuration. Add `require "write_geotag"` to luarc file. Relaunch Darktable and locate the new command in Darktable's keyboard shortcut preferences. Set a shortcut you'd like (ctrl-shift-T is a good choice) and you're good to go.

