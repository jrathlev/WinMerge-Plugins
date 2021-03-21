## IgnoreHtmlTags plugin

This plugin for WinMerge allows to compare *HTML* files ignoring all tags.
It consists of two plugin libraries:

**1. IgnoreHtmlTags:**
   *Unpack*: Extract the pure text from HTML file, prepend a number as marker
     to each text fragment and save the HTML code with all text fragments
     replaced by the assigned number as template for packing. Set line break
     markers to retain text wrapping.
   *Pack*: Load the HTML template created on unpacking and replace each fragment
     number with the assigned merged text and restore text wrapping.
     
**Note:     
*Ignore Spaces* should be set in the settings of *WinMerge*.

**Overview:**
Category: Unpacker
- File filter: `*.html`
- Packing: yes
- Settings dialog support: No
- Dependency: all HTML files

**2. IgnoreHtmlMarker:**
   *Prediff*: Ignore the fragment number at beginning of each line of text and
     line break markers

**Overview:**
- Category: Prediffer
- File filter: `*.html`
- Settings dialog support: No
- Dependency: all HTML files

The plugin is written in *Delphi 10 Seattle*

 
