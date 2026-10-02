# scyllaridae thumbnail warc

Capture a thumbnail of the homepage for a warc file.

This is done by:

1. Loading the WARC file from stdin
1. Parsing the WARC file for the homepage
1. Using headless chrome to capture a screenshot of the homepage (750px)
1. Printing the screenshot to stdout
