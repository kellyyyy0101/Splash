import pyttsx3
from blockext import *

engine = pyttsx3.init()

@command("speak %s")
def speak(input):
    engine.say(input)
    engine.runAndWait

run("Text To Speech", "tts", 12346)