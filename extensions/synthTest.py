import ctypes
import time

# Load the Windows multimedia library
winmm = ctypes.windll.winmm

# Define the MIDI handle type
HMIDIOUT = ctypes.c_uint32
PHMIDIOUT = ctypes.POINTER(HMIDIOUT)

# MIDI Message helper function
def make_midi_msg(status, data1, data2):
    """Pack MIDI bytes into a single 32-bit integer."""
    return status | (data1 << 8) | (data2 << 16)

def play_midi_example():
    # 1. Open the default MIDI mapper device (-1)
    h_midi_out = HMIDIOUT()
    device_id = -1  # MIDI_MAPPER
    
    # midiOutOpen flags: CALLBACK_NULL = 0
    result = winmm.midiOutOpen(ctypes.byref(h_midi_out), device_id, 0, 0, 0)
    if result != 0:
        print(f"Error opening MIDI device: {result}")
        return

    print("MIDI device opened successfully.")

    try:
        # 2. Change Instrument (Program Change)
        # Status byte: 0xC0 (Program Change) | Channel: 0x00 -> 0xC0
        # Common General MIDI Patch Numbers (0-127):
        # 0: Acoustic Grand Piano | 19: Church Organ | 38: Synth Bass 1 | 80: Synth Lead (Square)
        instrument = 19  # Church Organ
        msg_change_inst = make_midi_msg(0xC0, instrument, 0)
        winmm.midiOutShortMsg(h_midi_out, msg_change_inst)
        print(f"Changed instrument to GM Patch #{instrument}")
        time.sleep(0.5)

        # 3. Note On (Play a C Major Chord)
        # Status byte: 0x90 (Note On) | Channel: 0x00 -> 0x90
        # Velocity / Volume: 127 (Max)
        notes = [60, 64, 67]  # MIDI numbers for C4, E4, G4
        velocity = 127
        
        print("Playing C Major Chord...")
        for note in notes:
            msg_note_on = make_midi_msg(0x90, note, velocity)
            winmm.midiOutShortMsg(h_midi_out, msg_note_on)
        
        # Hold the notes for 2 seconds
        time.sleep(2.0)

        # 4. Note Off (Stop the notes)
        # Status byte: 0x80 (Note Off) | Channel: 0x00 -> 0x80
        print("Stopping notes...")
        for note in notes:
            msg_note_off = make_midi_msg(0x80, note, 0)
            winmm.midiOutShortMsg(h_midi_out, msg_note_off)
            
        time.sleep(0.5)

    finally:
        # 5. Clean up and close the device
        winmm.midiOutClose(h_midi_out)
        print("MIDI device closed.")

if __name__ == "__main__":
    play_midi_example()
