#!/bin/bash

# Directory for temporary files
TEMP_DIR="/tmp/peach_icon"
ICON_SET_DIR="/Users/mpy/CascadeProjects/rBUM/rBUM/rBUM/Assets.xcassets/AppIcon.appiconset"

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Compile and run Swift script to generate base image
swiftc -o "$TEMP_DIR/generate_icon" "scripts/generate_app_icon.swift"
"$TEMP_DIR/generate_icon"

# Required icon sizes for macOS
SIZES=(16 32 64 128 256 512 1024)

# Convert base PNG to all required sizes
for size in "${SIZES[@]}"; do
  sips -z $size $size "$TEMP_DIR/base.png" --out "$TEMP_DIR/icon_${size}x${size}.png"
  
  # Create 2x version if needed (except for 1024)
  if [ $size -ne 1024 ]; then
    cp "$TEMP_DIR/icon_${size}x${size}.png" "$ICON_SET_DIR/icon_${size}x${size}.png"
    sips -z $((size*2)) $((size*2)) "$TEMP_DIR/base.png" --out "$ICON_SET_DIR/icon_${size}x${size}@2x.png"
  else
    cp "$TEMP_DIR/icon_${size}x${size}.png" "$ICON_SET_DIR/icon_512x512@2x.png"
  fi
done

# Create Contents.json
cat > "$ICON_SET_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Clean up
rm -rf "$TEMP_DIR"

echo "App icon generation complete!"
