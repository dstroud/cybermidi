local mod = require 'core/mods'
-- local ip_address = wifi.ip  -- no work
-- print("DEBUG ip_address = " .. (ip_address or "nil"))
local ip_address = "192.168.1.18"
local port = 10111
local device_id = 17-- todo work on this. was using -1 to set off-limits to scripts

local my_midi = {
  name="midi_over_osc",
  connected=true,
}

function my_midi:send(data) end

function my_midi:note_on(note, vel, ch)
  osc.send({ip_address, port}, "/midi_over_osc", {"note_on", note, vel or 100, ch or 1})
end

function my_midi:note_off(note, vel, ch)
  osc.send({ip_address, port}, "/midi_over_osc", {"note_off", note, vel or 0, ch or 1})
end

-- TODO
function my_midi:pitchbend(val, ch) end
function my_midi:cc(cc, val, ch) end
function my_midi:key_pressure(note, val, ch) end
function my_midi:channel_pressure(val, ch) end
function my_midi:program_change(val, ch) end
function my_midi:stop()	end
function my_midi:continue()	end
function my_midi:clock() end

local fake_midi = {
  real_midi = midi,
}

local meta_fake_midi = {}

setmetatable(fake_midi, meta_fake_midi)

meta_fake_midi.__index = function(t, key)
	if key == 'vports' then
		local ret = {}
		for _, v in ipairs(t.real_midi.vports) do
			table.insert(ret, v)
		end
		table.insert(ret, my_midi)
		return ret
	end
	if key == 'devices' then
		local ret = {}
		for k, d in pairs(t.real_midi.devices) do
			ret[k] = d
		end
		ret[device_id] = {
			name="midi_over_osc",
			port=17,  -- midi.devices[device_id].port
			id=device_id,
		}
		return ret
	end
	if key == 'connect' then
		return function(idx)
			if idx == nil then
				idx = 1
			end
			if idx <= 16 then
				if t.real_midi.vports[idx].name == "midi_over_osc" then
					print("Connecting to midi_over_osc")
					return my_midi
				end
				return t.real_midi.connect(idx)
			end
			if idx == #t.real_midi.vports + 1 then
				return my_midi
			end
			return nil
		end
	end
	return t.real_midi[key]
end

mod.hook.register("script_pre_init", "midi-over-osc pre init", function()
  midi = fake_midi    
	local old_init = init
	init = function()
	  old_init()
    old_osc_event = osc.event

  	function osc.event(path, args, from)
  	  if path == "/midi_over_osc" then
  		  if type(midi.vports[device_id].event) == "function" then
  		    -- this is only going to work for note_on and note_off
  		    midi.vports[device_id].event(midi.to_data({type=args[1], note=args[2], vel=args[3], ch=args[4]}))
		    end
	    elseif old_osc_event ~= nil then 
    	  old_osc_event(path, args, from)
		  end
  	end
  	
  end
end)


mod.hook.register("script_post_cleanup", "midi_over_osc post cleanup", function()
	midi = fake_midi.real_midi
  osc.event = old_osc_event
end)