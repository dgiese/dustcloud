#!/usr/bin/env python3
import os
import csv

output_directory = "generated"
input_file = "audio_de.csv"
language = "de"
# text to speech engine (gtts or espeak)
engine = "gtts"

# import engine
if engine == "gtts":
    from gtts import gTTS

# read input file
filereader = csv.reader(open(input_file), delimiter=",")

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
    elif engine == "espeak":
        os.system("espeak-ng -v " + language + " '" + text + "' -w " + path)
