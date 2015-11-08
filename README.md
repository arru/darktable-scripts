Copy+import: import ordinary DCF flash memories
===============================================

### Features
* Copy and import images from camera memory cards (DCF system) directly into Darktable
* Optionally sort images manually into multiple import folders using an "inbox" system 
* Imports are sorted into subfolders, using user-configurable naming patterns
* Handles destination directories that may be temporarily unavailable (external disks)

###### Settings for
* Folder naming pattern
* Destination folder
* Multiple destination folders are set by adding them to a table in the script file
* Multiple destinations can have individual folder naming patterns

### Requirements
* [Exiftool](http://www.sno.phy.queensu.ca/~phil/exiftool/)
* For video _conversion:_ ffmpeg with libfaac
* Built and tested for Darktable 1.6

### Usage
Put in darktable/lua folder inside darktable's configuration. Add `require "copy_import"` to luarc file. Relaunch Darktable and locate the new command in Darktable's keyboard shortcut preferences. Set a shortcut you'd like (ctrl-I is a good choice) and you're good to go.

First time set preferences as desired. Mount camera memory card(s). Press shortcut and wait until done.

###### Multiple import destinations
If you like to sort your images by topic or some other scheme, the script supports that workflow too. Add your image folders to `alternate_dests` by following the example comments in the script file. Run the script once and an 'Inbox' folder will be added to each destination. When importing, sort your images by _copying_ them to one of the inboxes - unlike memory card images, inbox images will be __moved, not copied__ to their final destination. Run the script, and all images will be moved into their respective destination folder using the naming rules specified for each.

###### External disk inbox trick
If you'd like to be able to add new images to the inbox of a drive that is not currently mounted, do as follows:
1. Add the new drive to `alternate_dests` as above
1. Create an inbox folder in a suitable place on your _internal_ drive
1. Make a symlink _from_ the internal drive inbox _to_ the inbox on the external drive (replacing that folder with a symlink). The resulting symlink must still be named "Inbox", the folder on the internal drive can be named whatever you want.
1. Add images to the new inbox on the internal drive. Whenever the external drive is connected and the script is run, any images in the inbox will be moved to there and imported.

__Advise:__ there is a minor UX bug in Darktable when selecting directories in the preferences; the "shortcuts" to common directories in the menu will not work, that selection will be reset when the preferences window is closed. Instead, select "Other…" and navigate to your photo library manually.


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
Put in darktable/lua folder inside darktable's configuration. Add `require "geotag_io"` to luarc file. Relaunch Darktable and locate the new command in Darktable's keyboard shortcut preferences. Set a shortcut you'd like (ctrl-shift-T for write tag, ctrl-shift-R for reset is a good choice) and you're good to go.

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

Reveal: reveal selected image(s) in the (OSX) Finder
====================================================
### What it does
The script uses the Mac OSX-specific `open` command to reveal the image files for selected images in the Finder.

### Usage
Put in darktable/lua folder inside darktable's configuration. Add `require "autogroup"` to luarc file. Relaunch Darktable and locate the new command in Darktable's keyboard shortcut preferences. Set a shortcut you'd like.

Press shortcut and watch Finder windows appear, containing the selected images. If an image is missing, its parent folder will open along with an error message in Darktable.