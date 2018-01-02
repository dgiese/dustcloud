#!/usr/bin/env python3
import os
import csv

output_directory = "generated"
language = input("Write language according ISO-639-1 (ca, de, en, es): ")
input_file = "audio_" + language + ".csv"
# text to speech engine (gtts, espeak or macos)
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
    elif engine == "macos":
        # remove "-v Anna" if you want to use your system language, leave this as german default
        # format is recommendation from https://stackoverflow.com/a/9732070
        os.system("say -v Anna -o " + path + " --data-format=LEF32@22050 " + text)
