local mod = require 'core/mods'

mod.hook.register("script_pre_init", "midi-over-osc pre init", function() --todo system_post_startup
  midi_over_osc = {}
  local ip = wifi.ip
  print("MIDI-OVER-OSC: IP = " .. ip)
  midi_over_osc.ip = "192.168.1.18" --wifi.ip
  midi_over_osc.port = 10111
  
  midi_fn = {}  -- todo p0 local 
  function midi_fn:note_on(note, vel, ch)
    osc.send({midi_over_osc.ip, midi_over_osc.port}, "/midi-over-osc", {"note_on", note, vel or 100, ch or 1})
  end
  function midi_fn:note_off(note, vel, ch)
    osc.send({midi_over_osc.ip, midi_over_osc.port}, "/midi-over-osc", {"note_off", note, vel or 100, ch or 1})
  end

	for port, table in pairs(midi.vports) do
	  if table.name == "virtual" then
  	  print("MIDI-OVER-OSC: virtual port #" .. port)
  	  midi_over_osc.old_virtual = midi.vports[port] -- not sure if we need to restore this, but just in case
      
      -- for k, v in ipairs(midi_fn) do
      midi.vports[port].note_on = midi_fn.note_on
      midi.vports[port].note_off = midi_fn.note_off

      local old_init = init
    	init = function()
    	  old_init()
        old_osc_event = osc.event
      	function osc.event(path, args, from)
      	  print("MIDI-OVER-OSC: OSC received")
      	  if path == "/midi-over-osc" then
            if type(midi.vports[port].event) == "function" then -- .connected??
        		  midi.vports[port].event(midi.to_data({type=args[1], note=args[2], vel=args[3], ch=args[4]}))
            end
        	elseif old_osc_event ~= nil then 
          	  old_osc_event(path, args, from)
        	end
      	end
    	end
  	  break
    end
	end
end)

mod.hook.register("script_post_cleanup", "midi-over-osc post cleanup", function() -- todo system_pre_shutdown
  osc.event = old_osc_event
  midi.vports[port] = midi_over_osc.old_virtual -- just in case??
end)