#!/usr/bin/env python3

from PIL import Image, ImageDraw, ImageFont
import os

def create_icon(size, text, output_path):
    # Create a new image with a white background
    image = Image.new('RGB', (size, size), 'white')
    draw = ImageDraw.Draw(image)
    
    # Draw a blue rounded rectangle as background
    draw.rectangle([(0, 0), (size, size)], fill='#0066CC')
    
    # Draw text
    font_size = size // 4
    try:
        font = ImageFont.truetype('/System/Library/Fonts/SFNSMono.ttf', font_size)
    except:
        font = ImageFont.load_default()
    
    text_bbox = draw.textbbox((0, 0), text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    
    x = (size - text_width) // 2
    y = (size - text_height) // 2
    
    # Draw white text
    draw.text((x, y), text, fill='white', font=font)
    
    # Save the image
    image.save(output_path, 'PNG')

def main():
    # Icon sizes for macOS
    sizes = [16, 32, 128, 256, 512]
    
    # Create output directory
    output_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 
                             'rBUM/rBUM/Assets.xcassets/AppIcon.appiconset')
    os.makedirs(output_dir, exist_ok=True)
    
    # Generate icons
    for size in sizes:
        # 1x version
        create_icon(size, 'rBUM', os.path.join(output_dir, f'icon_{size}x{size}.png'))
        # 2x version
        create_icon(size * 2, 'rBUM', os.path.join(output_dir, f'icon_{size}x{size}@2x.png'))

if __name__ == '__main__':
    main()
