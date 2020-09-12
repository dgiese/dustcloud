#!/usr/bin/env python3

# Author: Dennis Giese [dennis@dontvacuum.me]
# Copyright 2017 by Dennis Giese

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

import csv
import glob
import os
import sys


def select_item(welcome_text, items):
    print(welcome_text)
    for i, item in enumerate(items):
        print('{}. {}'.format(i + 1, item))
    try:
        selected = input('Please select option by typing number (1-{}): '.format(len(items)))
        result = items[int(selected) - 1]
        return result
    except KeyboardInterrupt:
        print('User requested to exit')
        exit()
    except ValueError:
        print('Error! Please enter only one number')
        exit()
    except IndexError:
        print('Error! Please enter one number between 1-{}'.format(len(items)))
        exit()


available_audio = glob.glob('language/audio_*.csv')
input_file = select_item('Available localized audio instructions:', available_audio)
language = input_file.split('_')[-1].split('.')[0]
output_directory = "generated_{}".format(language)
sound_password = "r0ckrobo#23456"

tts_engines = ['gtts']
if sys.platform == 'darwin':
    tts_engines.append('macos')
if os.system('espeak --version > /dev/null 2>&1') == 0:
    tts_engines.append('espeak')
if os.system('espeak-ng --version > /dev/null 2>&1') == 0:
    tts_engines.append('espeak-ng')
if os.system('aws --version > /dev/null 2>&1') == 0:
    tts_engines.append('aws')
engine = select_item('Available TTS engines:', tts_engines)

if engine == 'gtts':
    if os.system('ffmpeg -version > /dev/null 2>&1') != 0:
        print('gTTS engine requires ffmpeg for converting mp3 to wav. Install it by typing: `sudo apt install ffmpeg` in terminal.')
        exit(0)
    else:
        # import engine
        from gtts import gTTS

if engine == 'aws':
    genders = ['female', 'male']
    gender = select_item('Available Voices:', genders)

if engine == 'macos':
    if os.system('ffmpeg -version > /dev/null 2>&1') != 0:
        print('macos engine requires ffmpeg for converting aiff to wav.')
        exit(0)

# read input file
try:
    filereader = csv.reader(open(input_file), delimiter=",")
except:
    print('Error opening file {}'.format(input_file))
    exit()

# create output folder
if not os.path.exists(output_directory):
    os.makedirs(output_directory)

# generate audio
for filename, text in filereader:
    print(filename)
    path = os.path.join(output_directory, filename)
    if engine == "gtts":
        tts = gTTS(text=text, lang=language, slow=False)
        # save mp3 and convert to mp3
        tts.save("{}.mp3".format(path))
        os.system("ffmpeg -hide_banner -loglevel panic -i {0}.mp3 {0}".format(path))
        os.remove("{}.mp3".format(path))
    elif engine == "aws":
        # https://docs.aws.amazon.com/polly/latest/dg/voicelist.html
        if language == "de":
            if gender == "female":
                voice = "Vicki"
            if gender == "male":
                voice = "Hans"
        elif language == "fr":
            if gender == "female":
                voice = "Celine"
            if gender == "male":
                voice = "Mathieu"
        elif language == "ca":
            voice = "Chantal"  # No male voice
        elif language == "es":
            if gender == "female":
                voice = "Conchita"
            if gender == "male":
                voice = "Enrique"
        elif language == "pl":
            if gender == "female":
                voice = "Ewa"
            if gender == "male":
                voice = "Jacek"
        elif language == "ru":
            if gender == "female":
                voice = "Tatyana"
            if gender == "male":
                voice = "Maxim"
        else:  # if language not available, use en
            if gender == "female":
                voice = "Amy"
            if gender == "male":
                voice = "Brian"
        os.system("aws polly synthesize-speech --output-format mp3 --voice-id {} --text \"{}\" {}.mp3".format(voice, text, path))
        os.system("ffmpeg -hide_banner -loglevel panic -i {0}.mp3 {0}".format(path))
        os.remove("{}.mp3".format(path))
    elif engine == "espeak":
        os.system("espeak -v {} \"{}\" -w {}".format(language, text, path))
    elif engine == "espeak-ng":
        os.system("espeak-ng -v {} \"{}\" -w {}".format(language, text, path))
    elif engine == "macos":
        # remove "-v Anna" if you want to use your system language, leave this as german default
        # direct output as wav isn't readable by the robot
        os.system("say -v Anna -o {}.aiff {}".format(path, text))
        os.system("ffmpeg -hide_banner -loglevel panic -i {0}.aiff {0}".format(path))
        os.remove("{}.aiff".format(path))

if os.system('cd {} && tar zc *.wav | ccrypt -e -K "{}" > {}.pkg'.format(output_directory, sound_password, language)) == 0:
    print("\nGenerated encrypted sound package at {}/{}.pkg".format(output_directory, language))
