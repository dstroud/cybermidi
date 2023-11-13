local mod = require 'core/mods'
-- local ip_address = wifi.ip  -- no work
-- print("DEBUG ip_address = " .. (ip_address or "nil"))
-- local ip_address = "192.168.1.18"
local port = 10111
local device_id = 17-- todo work on this. was using -1 to set off-limits to scripts

local my_midi = {
  name="midi_over_osc",
  connected=true,
}
function my_midi:send(data) end
function my_midi:note_on(note, vel, ch)
  osc.send({wifi.ip, port}, "/midi_over_osc_note_on", {note, vel, ch})
end
function my_midi:note_off(note, vel, ch)
  osc.send({wifi.ip, port}, "/midi_over_osc_note_off", {note, vel, ch})
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

-- todo: consider breaking into system_post_startup and script_pre_init hooks?
mod.hook.register("script_pre_init", "midi_over_osc pre init", function()
-- mod.hook.register("system_post_startup", "midi_over_osc pre init", function()
	-- print("midi over osc mod registered")
	midi = fake_midi    
	
	-- trouble! will be superceded by scripts that define osc.event()
	-- probably need to redefine _norns.osc.event to address this
	function osc.event(path,args,from)
		if type(midi.vports[device_id].event) == "function" then -- necessary?
		-- print("midi.vports[" .. device_id .. "].event undefined")
	-- else
			if path == "/midi_over_osc_note_on" then
				-- print("osc note_on")
				midi.vports[device_id].event(midi.to_data({type = "note_on", note = args[1], vel = args[2], ch = args[3]}))
			elseif path == "/midi_over_osc_note_off" then
				midi.vports[device_id].event(midi.to_data({type = "note_off", note = args[1], vel = args[2], ch = args[3]}))
			end
		end
	end
end)

mod.hook.register("script_post_cleanup", "midi_over_osc post cleanup", function()
-- mod.hook.register("system_pre_shutdown", "midi_over_osc post cleanup", function()
	midi = fake_midi.real_midi
	osc.event = nil
end)