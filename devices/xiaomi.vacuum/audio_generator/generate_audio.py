#!/usr/bin/env python3
import os
import csv
import glob
import sys


def select_item(welcome_text, items):
    print(welcome_text)
    for i, item in enumerate(items):
        print('{}. {}'.format(i+1, item))
    try:
        selected = input('Please select option by typing number (1-{}): '.format(len(items)))
        result = items[int(selected)-1]
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

output_directory = "generated"
available_audio = glob.glob('language/audio_*.csv')
input_file = select_item('Available localized audio instructions:', available_audio)
language = input_file.split('_')[-1].split('.')[0]
output_directory = "generated_" + language
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
    path = output_directory + "/" + filename
    if engine == "gtts":
        tts = gTTS(text=text, lang=language, slow=False)
        # save mp3 and convert to mp3
        tts.save(path + ".mp3")
        os.system("ffmpeg -hide_banner -loglevel panic -i " + path + ".mp3 " + path)
        os.remove(path + ".mp3")
    elif engine == "aws":
        os.system("aws polly synthesize-speech --output-format mp3 --voice-id Vicki --text '" + text + "' " + path + ".mp3")
        os.system("ffmpeg -hide_banner -loglevel panic -i " + path + ".mp3 " + path)
        os.remove(path + ".mp3")
    elif engine == "espeak":
        os.system("espeak -v " + language + " '" + text + "' -w " + path)
    elif engine == "espeak-ng":
        os.system("espeak-ng -v " + language + " '" + text + "' -w " + path)
    elif engine == "macos":
        # remove "-v Anna" if you want to use your system language, leave this as german default
        # format is recommendation from https://stackoverflow.com/a/9732070
        os.system("say -v Anna -o " + path + " --data-format=LEF32@22050 " + text)

if os.system('cd %s && tar zc *.wav | ccrypt -e -K "%s" > %s.pkg' % (output_directory, sound_password, language)) == 0:
    print("\nGenerated encrypted sound package at %s/%s.pkg" % (output_directory, language))
