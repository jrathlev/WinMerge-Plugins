**UnpackGz plugin**

This plugin for WinMerge allows to unpack a gz file before comparing
and pack to new gz file after merging.
Only files with extension "gz" will be unpacked, all other files
are loaded without gz handling.

Notes on coding of filenames
The existing standard for the gzip format (RFC1952 of 1996) calls for the filename 
to be stored in the file header using the ISO-8859-1 character set. I could not 
find any recommendations as to how to handle Unicode filenames.

The current Linux version of the program gzip used for creating and reading gz 
archives differs from the above standard and stores filenames in UTF-8 format. 
The OS byte in the header is set to 3 (Unix).

The plugin will check the OS byte in the header:
OS = 0 (FAT) => read filename as ISO-8859
OS = 11 (NTFS) => read filename as UTF-8

Notes on files > 4 GB
The existing standard for the gzip format (RFC1952 of 1996) reserves a 32 bit 
value for the length of the uncompressed file. For files > 4 GB this value is 
written module 2^32. Like many file archive programs (e.g. 7-zip), the plugin 
supports the use of an extra field with the signature 0x0100 containing the 
real file size.

Overview:
Category: Unpacker
File filter: *.gz
Packing: Yes
Settings dialog support: No
Dependency: gzip

The plugin is written in Delphi 10 Seattle

J. Rathlev, D-24222 Schwentinental, March 2021

