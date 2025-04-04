#!/usr/bin/env python3

from PIL import Image, ImageDraw, ImageFont
from inky.auto import auto
import sys
import os

def create_config_display(ssid, password, ip):
    # Initialize the display
    display = auto(ask_user = True, verbose = True)
    
    # Create a new image with white background
    width = display.WIDTH
    height = display.HEIGHT
    image = Image.new("P", (width, height), display.WHITE)
    draw = ImageDraw.Draw(image)
    
    # Load font
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
    except:
        font = ImageFont.load_default()
    
    # Title
    draw.text((10, 10), "InkyPi Configuration", font=font, fill=display.BLACK)
    
    # WiFi Hotspot Info
    y = 40
    draw.text((10, y), "WiFi Hotspot:", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), f"SSID: {ssid}", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), f"Password: {password}", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), f"IP: {ip}", font=font, fill=display.BLACK)
    
    # Configuration Options
    y += 40
    draw.text((10, y), "Configuration Options:", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), "1. Connect to WiFi Hotspot", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), "2. SSH: ssh pi@192.168.4.1", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), "3. Edit /boot/eink/wifi.yml", font=font, fill=display.BLACK)
    
    # Instructions
    y += 40
    draw.text((10, y), "Instructions:", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), "1. Connect to WiFi hotspot", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), "2. SSH in or edit wifi.yml", font=font, fill=display.BLACK)
    y += 25
    draw.text((20, y), "3. Reboot to apply changes", font=font, fill=display.BLACK)
    
    # Update the display
    display.set_image(image)
    display.show()

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: display-hotspot.py <ssid> <password> <ip>")
        sys.exit(1)
    
    create_config_display(sys.argv[1], sys.argv[2], sys.argv[3]) 