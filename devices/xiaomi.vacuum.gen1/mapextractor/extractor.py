#!/usr/bin/env python3
# See https://github.com/marcelrv/XiaomiRobotVacuumProtocol/blob/master/RRMapFile/RRFileFormat.md

import sqlite3, gzip, io, struct, sys, argparse
from datetime import datetime


def make_file_name(output_folder, timestamp, map_index):
    return '%s/%s_%d' % (output_folder, datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d_%H.%M.%S'), map_index)


def read_int(data):
    return struct.unpack('<i', data.read(4))[0]


def read_short(data):
    return struct.unpack('<h', data.read(2))[0]


def charger(data):
    pos_x = read_int(data)
    pos_y = read_int(data)
    return (pos_x, pos_y)


def grayscale_color(pixel):
    if pixel == 1:  # wall pixel
        return 128  # gray color
    else:  # outside, inside or unknown pixel
        return pixel


def rgb_color(pixel):
    if pixel == 1:  # wall pixel
        return [105, 207, 254]
    elif pixel == 255:  # inside pixel
        return [33, 115, 187]
    else:  # outside or unknown pixel
        return [pixel, pixel, pixel]


# http://netpbm.sourceforge.net/doc/pgm.html
def export_image_grayscale(data, image_len, timestamp, map_index, output_folder):
    file_name = make_file_name(output_folder, timestamp, map_index) + '.pgm'

    if image_len == 0:
        print('Warning: %s - empty image. Will not extract.' % file_name, file=sys.stderr)
        return
    else:
        print('Extracting: %s' % file_name)

    top = read_int(data)
    left = read_int(data)
    height = read_int(data)
    width = read_int(data)

    pixels = [grayscale_color(p) for p in data.read(image_len)]

    with open(file_name, 'wb') as file:
        file.write(('P5\n%d %d\n255\n' % (width, height)).encode())
        for h in range(height)[::-1]:
            file.write(bytes(pixels[h * width: h * width + width]))


# http://netpbm.sourceforge.net/doc/ppm.html
def export_image_colored(data, image_len, timestamp, map_index, output_folder):
    file_name = make_file_name(output_folder, timestamp, map_index) + '.ppm'

    if image_len == 0:
        print('Warning: %s - empty image. Will not extract.' % file_name, file=sys.stderr)
        return
    else:
        print('Extracting: %s' % file_name)

    top = read_int(data)
    left = read_int(data)
    height = read_int(data)
    width = read_int(data)
    rgb_width = width * 3

    pixels = [rgb for pixel in data.read(image_len) for rgb in rgb_color(pixel)]

    with open(file_name, 'wb') as file:
        file.write(('P6\n%d %d\n255\n' % (width, height)).encode())
        for h in range(height)[::-1]:
            file.write(bytes(pixels[h * rgb_width: h * rgb_width + rgb_width]))


def path(data, path_len, charger_pos, timestamp, map_index, output_folder):
    set_point_length = read_int(data)
    set_point_size = read_int(data)
    set_angle = read_int(data)
    image_width = (read_short(data), read_short(data))
    
    # extracting path
    path = [(read_short(data), read_short(data)) for _ in range(set_point_length)]

    # rescaling coordinates
    path = [((p[0]) // 50, (p[1]) // 50) for p in path]
    charger_pos = ((charger_pos[0]) // 50, (charger_pos[1]) // 50)

    # Creating image
    width, height = image_width[0] // 25, image_width[1] // 25

    file_name = make_file_name(output_folder, timestamp, map_index) + '_path.pgm'
    
    pixels = [0] * width * height

    for x, y in path:
        pixels[y * width + x] = 155

    for off_x in range(-2, 2):
        for off_y in range(-2, 2):
            idx = (charger_pos[1] + off_y) * width + charger_pos[0] + off_x
            pixels[idx] = 255

    with open(file_name, 'wb') as file:
        file.write(('P5\n%d %d\n255\n' % (width, height)).encode())
        for h in range(height)[::-1]:
            file.write(bytes(pixels[h * width: h * width + width]))


def parse(timestamp, bytes, do_coloring, output_folder):
    data = gzip.GzipFile(fileobj=bytes)

    magic = data.read(2)
    header_len = read_short(data)
    checksum_pointer = data.read(4)
    major_ver = read_short(data)
    minor_ver = read_short(data)
    map_index = read_int(data)
    map_sequence = read_int(data)

    while True:
        block_type = read_short(data)
        unknown = data.read(2)
        block_size = read_int(data)

        if block_type == 1:
            charger_pos = charger(data)
        elif block_type == 2:
            if do_coloring:
                export_image_colored(data, block_size, timestamp, map_index, output_folder)
            else:
                export_image_grayscale(data, block_size, timestamp, map_index, output_folder)
        elif block_type == 3:
            path(data, block_size, charger_pos, timestamp, map_index, output_folder)
        else:
            break


def main():
    parser = argparse.ArgumentParser(description='Map Extractor for Xiaomi Vacuum.\n'.format(sys.argv[0]))
    parser.add_argument('-c', '--color', dest='color', action='store_true', help='Color extracted image')
    parser.add_argument('-o', '--output', dest='output', type=str, default='.', help='Output folder')
    parser.add_argument('-f', '--file', dest='file', type=str, required=True,
                        help="Path to database file (found in '/mnt/data/rockrobo/robot.db' on vacuum)")

    args, external = parser.parse_known_args()

    file = args.file
    do_coloring = args.color
    output_folder = args.output

    with sqlite3.connect(file) as conn:
        for row in conn.cursor().execute('SELECT * FROM cleanmaps'):
            parse(row[0], io.BytesIO(row[2]), do_coloring, output_folder)


if __name__ == '__main__':
    main()
