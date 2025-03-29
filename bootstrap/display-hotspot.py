#!/usr/bin/env python3

from PIL import Image, ImageDraw, ImageFont
import os
import sys
from inky.auto import auto
import time

def create_hotspot_display(ssid, password, ip):
    # Initialize the display
    try:
        display = auto()
    except Exception as e:
        print(f"Error initializing display: {e}")
        return False

    # Create a new image with white background
    width = display.WIDTH
    height = display.HEIGHT
    image = Image.new("P", (width, height))
    draw = ImageDraw.Draw(image)

    # Try to load a font, fallback to default if not available
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 20)
    except:
        font = ImageFont.load_default()

    # Calculate text positions
    title = "WiFi Hotspot Active"
    title_bbox = draw.textbbox((0, 0), title, font=font)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (width - title_width) // 2

    # Draw title
    draw.text((title_x, 20), title, display.BLACK, font=font)

    # Draw separator line
    draw.line([(20, 50), (width-20, 50)], display.BLACK, 2)

    # Draw connection details
    details = [
        f"SSID: {ssid}",
        f"Password: {password}",
        f"IP: {ip}",
        "",
        "Connect to configure WiFi"
    ]

    y_pos = 70
    for line in details:
        text_bbox = draw.textbbox((0, 0), line, font=font)
        text_width = text_bbox[2] - text_bbox[0]
        x_pos = (width - text_width) // 2
        draw.text((x_pos, y_pos), line, display.BLACK, font=font)
        y_pos += 30

    # Display the image
    try:
        display.set_image(image)
        display.show()
        return True
    except Exception as e:
        print(f"Error displaying image: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: display-hotspot.py <ssid> <password> <ip>")
        sys.exit(1)

    ssid = sys.argv[1]
    password = sys.argv[2]
    ip = sys.argv[3]

    success = create_hotspot_display(ssid, password, ip)
    sys.exit(0 if success else 1) 