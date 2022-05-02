#!/bin/sh

# Requires Inkscape and ImageMagick

inkscape -w 256 -h 256 ./icon.svg -o ./zig-cache/icon.png
convert ./zig-cache/icon.png -define icon:auto-resize=256,128,64,48,32,16 icon.ico
