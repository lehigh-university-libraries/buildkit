# scyllaridae thumbnail zip

Capture a thumbnail of a ZIP file.

This is done by:

1. Passing the ZIP contents to the `tree` command
1. Using imagemagick to capture a screenshot of the output (750px)
1. Printing the screenshot to stdout
