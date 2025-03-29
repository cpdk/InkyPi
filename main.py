#!/usr/bin/env python3

from PIL import Image, ImageDraw, ImageFont
import inky.auto
import time
import logging
import os

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/eink-app.log'),
        logging.StreamHandler()
    ]
)

def main():
    try:
        # Initialize the display
        display = inky.auto.auto()
        
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
        
        # Draw some text
        draw.text((10, 10), "InkyPi Application", font=font, fill=display.BLACK)
        draw.text((10, 40), "Running successfully!", font=font, fill=display.BLACK)
        
        # Update the display
        display.set_image(image)
        display.show()
        
        logging.info("Display updated successfully")
        
    except Exception as e:
        logging.error(f"Error in main application: {e}")
        raise

if __name__ == "__main__":
    main() 