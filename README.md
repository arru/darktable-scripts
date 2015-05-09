Write geotag: write geotags back to file exif data
==================================================

### What it does
Darktable allows you to geotag images using both .gpx track data, or point-and-click. There is no way, however, to write this data into the original image file as EXIF. This script does exactly that, allowing you to rely only on Darktable for geotagging your images in a persistent and reliable way.

### Features
* Writes EXIF geotags as assigned in Darktable to image files
* Re-loads EXIF geotags from image file into Darktable

###### Settings for
* Preserving original modification date
* Retaining original image file
* Writing only to files without existing EXIF geotags

### Requirements
* [Exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/)
* Built and tested for Darktable 1.6

### Usage
Put in darktable/lua folder inside darktable's configuration. Add `require "write_geotag"` to luarc file. Relaunch Darktable and locate the new command in Darktable's keyboard shortcut preferences. Set a shortcut you'd like (ctrl-shift-T for write tag, ctrl-shift-R for reset is a good choice) and you're good to go.

Autogroup: group images by shooting time
========================================

### What it does
Automatically making groups out of selected images, based on detected photographer behavior.

### Features
Statistically finds the likely time interval for serial images within the selection, and uses that time value to group images with less time inbetween.

###### Settings for
* Maximum and minimum time between images to be grouped
* Whether to only use auto grouping (and failing if no groups are found by the algorithm), or falling back on image groups below minimum time interval ("guaranteed grouping")

### Usage
Put in darktable/lua folder inside darktable's configuration. Add `require "autogroup"` to luarc file. Relaunch Darktable and locate the new command in Darktable's keyboard shortcut preferences. Set a shortcut you'd like (ctrl-G is a good choice).

The script works best on a reasonably large set of images taken, say, during a single trip, or within the same month. For a _small selection_, < 20 images or so, the autogroup algorithm may not give satisfactory results. For _very large sets_ (an entire year or more), results will not be optimal since one single grouping time will be found and applied to all images, while they may have been taken in differing circumstances.

Take your time to tweak the short and long time settings, if images are not grouped in desired way, lower or increase the respective settings to cover the interval between the troublesome images. Also, as stated below, try to make each selection of images shot during similar circumstances.

_Although these scripts has been written with fail safety in mind, the author of this software takes no responsibility for direct, indirect, incidental, special, exemplary, or consequential damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business interruption). See license for complete disclaimer. Do your backups!_