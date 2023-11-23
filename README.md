## C Y B E R M I D I

>*Listen up, kid. I don’t need to know how you ended up acquiring not one but *two* Norns-class cyberdecks. But slingin’ two ‘decks without a proper setup is like waltzing into corpo HQ without a plan.*

>*You've got the hardware, sure. It’s gonna take more than just showin' off your chrome to be a legit Netrunner. Do the math: ya got two decks and one interface plug, yeah? That's like tryin' to ride a bike with one wheel. We need to link those bad boys up, turn 'em into a seamless unit with bidirectional comms. Welcome to the sordid world of M.I.D.I.*

>*Now, I get it. Not everyone's got the eddies for a next-gen 2host setup. Lucky for you, my fixer's got a line on a 'less-than-legitimate' option. It's a black-market mod, and yeah, might induce a touch of brain-burn here and there, but in this biz, risk is the name of the game. It’ll get the job done, it’s nanomachine-proof, and here’s the kicker—it’s free.*

>*I'm talkin' CyberMIDI: wireless transmission of M.I.D.I. between ‘decks. Give me a minute to jack in and upload the mod, and I’ll have your hardware singing in harmony. All I need in return is a little job from you. Consider it a favor among friends in the neon-soaked shadows. So, what's the verdict, choom? You in?"*


### What it is
A mod to send MIDI between Norns over IP.

### How to use it
1. Run `;install https://github.com/dstroud/cybermidi` in Maiden.
2. Enable the mod in SYSTEM>>MODS>>E3 (+ symbol) and restart.
3. Configure mod via SYSTEM>>MODS>>CYBERMIDI>>K3.
4. Use E2 to navigate and E3 to change values. K3 refreshes LAN devices.
5. `LAN` shows devices on network with the mod. `Manual` allows entering your own IP. Can also loopback to localhost.
6. Settings are applied immediately (watch out for hanging notes) and persist on reboot.
7. Enable a "virtual" MIDI port in SYSTEM>>DEVICES>>MIDI. Use this to send and receive MIDI in your script.

### Notes:
- System-level MIDI (MIDI clock and CC PMAP) don't respond to the "virtual" MIDI interface. Maybe someone wants to help look into this? At least you can use Link for sync.
-  Other than clock (see above), other system-defined types of MIDI should work. I've really only tested note on/off so let me know if you see issues.
