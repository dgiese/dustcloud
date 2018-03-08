"""
#!/usr/bin/env python3

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

"""
import argparse
import io
from PIL import Image, ImageDraw, ImageChops


def build_map(slam_log_data, map_image_data):
    """
    Parses the slam log to get the vacuum path and draws the path into
    the map. Returns the new map as a BytesIO.

    Thanks to CodeKing for the algorithm!
    https://github.com/dgiese/dustcloud/issues/22#issuecomment-367618008
    """
    map_image = Image.open(io.BytesIO(map_image_data))
    map_image = map_image.convert('RGBA')

    # calculate center of the image
    center_x = map_image.size[0] / 2
    center_y = map_image.size[0] / 2

    # rotate image by -90°
    map_image = map_image.rotate(-90)

    red = (255, 0, 0, 255)
    grey = (125, 125, 125, 255)  # background color
    transparent = (0, 0, 0, 0)

    # prepare for drawing
    draw = ImageDraw.Draw(map_image)

    # loop each line of slam log
    prev_pos = None
    for line in slam_log_data.split("\n"):
        # find positions
        if 'estimate' in line:
            d = line.split('estimate')[1].strip()

            # extract x & y
            y, x, z = map(float, d.split(' '))

            # set x & y by center of the image
            # 20 is the factor to fit coordinates in in map
            x = center_x + (x * 20)
            y = center_y + (y * 20)

            pos = (x, y)
            if prev_pos:
                draw.line([prev_pos, pos], red)
            prev_pos = pos

    # draw current position
    def ellipsebb(x, y):
        return x-3, y-3, x+3, y+3
    draw.ellipse(ellipsebb(x, y), red)

    # rotate image back by 90°
    map_image = map_image.rotate(90)

    # crop image
    bgcolor_image = Image.new('RGBA', map_image.size, grey)
    cropbox = ImageChops.subtract(map_image, bgcolor_image).getbbox()
    map_image = map_image.crop(cropbox)

    # and replace background with transparent pixels
    pixdata = map_image.load()
    for y in range(map_image.size[1]):
        for x in range(map_image.size[0]):
            if pixdata[x, y] == grey:
                pixdata[x, y] = transparent

    temp = io.BytesIO()
    map_image.save(temp, format="png")
    return temp


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="""
Process the runtime logs of the vacuum (SLAM_fprintf.log, navmap*.ppm from /var/run/shm)
and draw the path into the map. Outputs the map as a PNG image.
    """)

    parser.add_argument(
        "-slam",
        default="SLAM_fprintf.log",
        required=False)
    parser.add_argument(
        "-map",
        required=True)
    parser.add_argument(
        "-out",
        required=False)
    args = parser.parse_args()

    with open(args.slam) as slam_log:
        with open(args.map, 'rb') as mapfile:
            augmented_map = build_map(slam_log.read(), mapfile.read(), )

    out_path = args.out
    if not out_path:
        out_path = args.map[:-4] + ".png"
    if not out_path.endswith(".png"):
        out_path += ".png"

    with open(out_path, 'wb') as out:
        out.write(augmented_map.getvalue())
