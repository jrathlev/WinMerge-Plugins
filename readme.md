# Delphi Plugins

## IgnorePoComments

Remove all comment lines starting with "#" from po files. 

 * No packing (no save).
 * Event: `FILE_PACK_UNPACK`
 * File filter: `.po`
 
## UnpackGz

Unpack a *gz* file before comparing and pack to new *gz* file after merging. 

 * Event: `FILE_PACK_UNPACK`
 * File filter: `.gz`
  
 
