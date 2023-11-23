## C Y B E R M I D I

>*Listen up, kid. I don’t need to know how you ended up acquiring not one but *two* Norns-class cyberdecks. But slingin’ two ‘decks without a proper setup is like waltzing into corpo HQ without a plan.*

>*You've got the hardware, sure. It’s gonna take more than just showin' off your chrome to be a legit Netrunner. Do the math: ya got two decks and one interface plug, yeah? That's like tryin' to ride a bike with one wheel. We need to link those bad boys up, turn 'em into a seamless unit with bidirectional comms. Welcome to the sordid world of M.I.D.I.*

>*Now, I get it. Not everyone's got the eddies for a next-gen 2host setup. Lucky for you, my fixer's got a line on a 'less-than-legitimate' option. It's a black-market mod, and yeah, might induce a touch of brain-burn here and there, but in this biz, risk is the name of the game. It’ll get the job done, it’s nanomachine-proof, and here’s the kicker—it’s free.*

>*I'm talkin' CyberMIDI: wireless transmission of M.I.D.I. between ‘decks. Give me a minute to jack in and upload the mod, and I’ll have your hardware singing in harmony. All I need in return is a little job from you. Consider it a favor among friends in the neon-soaked shadows. So, what's the verdict, choom? You in?"*


### What it is
This is a Norns mod to send MIDI notes over the network using OSC. It seems to work okay but I haven't really tested it much so I hope it wasn't a big waste of time.

### How to use it
1. Run `;install https://github.com/dstroud/cybermidi` in Maiden.
2. Enable the mod in SYSTEM>>MODS>>E3 (a + symbol should appear).
3. Restart and launch a script.
4. To choose which device to send MIDI to, go to SYSTEM>>MODS>>CYBERMIDI and press K3.
5. When the `LAN`, setting is selected, use K3 to search for devices on your subnet with the mod installed and a script open.
6. E2 will change focus so you can browse devices on the network or switch from `LAN` to `Manual` IP mode.
7. In your script, you'll use the "virtual" port to send and receive MIDI. You can change the vport in SYSTEM>>MIDI>>DEVICES but not when the script is running.

### Notes:
- It looks like the system MIDI bits (MIDI clock and CC PMAP) don't respond to the "virtual" MIDI interface. Maybe someone wants to look into this?
-  I've really only tested note on/off but I added everything except for System Real Time messages. You can use Link for sync.
- Hotswapping vports doesn't work yet. I'll probably fix this at some point but for now just quit the script, change ports, and relaunch.
