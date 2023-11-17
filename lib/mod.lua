local mod = require 'core/mods'
-- local ip_address = wifi.ip  -- no work
-- print("DEBUG ip_address = " .. (ip_address or "nil"))
local ip_address = "192.168.1.18" -- todo!
local port = 10111
-- local midi_over_osc_id = -2    -- populate from global then kill globals
-- local midi_over_osc_vport = 18

-- debug function. remove!
function vp(idx)
  local vp = midi.vports[idx]
  print("id", idx)
  print("name", vp.name)
  print("connected", vp.connected)
  print("event", type(vp.event))
  print("device", type(vp.event))  
end  

local my_midi = {
  name = "MIDI-OVER-OSC",
  connected = true,
  -- device = midi_over_osc_id  -- todo: test. Not present for nbout FWIW. Is set when connecting 
}

function my_midi:send(data) end

function my_midi:note_on(note, vel, ch)
  print("sending note_on")
  osc.send({ip_address, port}, "/midi-over-osc", {"note_on", note, vel or 100, ch or 1})
end

function my_midi:note_off(note, vel, ch)
  osc.send({ip_address, port}, "/midi-over-osc", {"note_off", note, vel or 0, ch or 1})
end

-- TODO
function my_midi:pitchbend(val, ch) end
function my_midi:cc(cc, val, ch) end
function my_midi:key_pressure(note, val, ch) end
function my_midi:channel_pressure(val, ch) end
function my_midi:program_change(val, ch) end
function my_midi:stop()	end
function my_midi:continue()	end
function my_midi:clock() end -- likely would need redefining Midi.update_connected_state

local fake_midi = {
  real_midi = midi,
}

local meta_fake_midi = {}

setmetatable(fake_midi, meta_fake_midi)


meta_fake_midi.__index = function(t, key)

	if key == 'vports' then
		local ret = {}
		-- print("meta vports accessed")
		for _, v in ipairs(t.real_midi.vports) do
		  
		  -- -- this sets the port correctly when changed via Devices menu.
		  -- -- todo: won't be recognized until script restart
		  -- -- after relaunching script sometimes it gets confused, e.g.:
		  -- -- tab.print(midi.vports[7].connected) == true
		  -- -- tab.print(midi.real_midi.vports[7].connected) == false
		  -- if v.name == "MIDI-OVER-OSC" then
			 -- print("setting vport/device.port to " .. _)
			 -- midi_over_osc_vport = _
			 -- midi.devices[midi_over_osc_id].port = midi_over_osc_vport
		  -- end
		  
			table.insert(ret, v)
		  
		end
			
			
    -- print("setting vports[" .. midi_over_osc_vport .. "] to my_midi")
    -- print("my_midi.name = " .. (my_midi.name or "nil"))
    -- print("my_midi.connected = " .. (tostring(my_midi.connected or nil)))
		ret[midi_over_osc_vport] = my_midi


		-- print("post-reading from ret")
		-- print(ret[midi_over_osc_vport].name)
		
		return ret
	end
	
	if key == 'devices' then
		local ret = {}
		for k, d in pairs(t.real_midi.devices) do
			ret[k] = d
		end
		ret[midi_over_osc_id] = {
			name="MIDI-OVER-OSC",
			port=midi_over_osc_vport, -- todo: doesn't reflext vport changes until mod re-init
			id=midi_over_osc_id,
			-- ** todo: switching vport 17 to 5 does set vport name but vport.connected stays on port 17. Probably because it's pulling from here.
			-- looks as if event placed here can also fire, fwiw (untested)
		}
		return ret
	end
	
	if key == 'connect' then
		return function(idx)
			if idx == nil then
				idx = 1
			end
			
  --     -- shitty at the moment but the idea is this:
  --     -- if idx > 16 and idx == midi_over_osc_vport then return my_midi
  --     -- else return t.real_midi.connect(idx)
  --     -- needs to be tested with nb port 17
  --     -- probably interacts with vport flow which is wip
			
		-- 	if idx <= 16 then
		-- 	  if idx == midi_over_osc_vport then
		-- 	    print("Connecting to MIDI-OVER-OSC vport <= 16: " .. idx)
		--     end
		-- 	  return t.real_midi.connect(idx)
		-- 	end

  --     if idx > 16 then
  --       if idx ~= midi_over_osc_vport then
  --         print("idx > 16 but not MIDI-OVER-OSC (nbout?):" .. idx)
		-- 	    return t.real_midi.connect(idx) --??
  --       else
		-- 	    print("Connecting to MIDI-OVER-OSC vport > 16: " .. idx)
		-- 	    return my_midi
		--     end
  --     end


      -- in conjunction with vport option 3 above
      if idx == midi_over_osc_vport then
        print("connecting to my_midi")
        return my_midi
      else
        print("passing through midi.connect")
        return t.real_midi.connect(idx)
      end
 
			return nil
		end
	end
	
	return t.real_midi[key]
end

mod.hook.register("script_pre_init", "midi-over-osc pre init", function()

  

  -- todo clean all this crap up
  -- also check handling with no devices/ports
  local function min_index(tbl)
    local minimum = 0
    for key, _ in pairs(tbl) do
      if key < minimum then
        minimum = key
      end
    end
    return minimum == 1 and 0 or minimum
  end

  local function max_index(tbl)
    local maximum = 0
    for key, _ in pairs(tbl) do
      if key > maximum then
        maximum = key
      end
    end
    return maximum
  end
  
  for k, v in pairs(midi.vports) do
    -- use last set vport where possible
    if v.name == 'MIDI-OVER-OSC' then
      print("Existing midi-over-osc vport found")
      midi_over_osc_vport = k
      break
    end
  end
  -- else tack on to to the end (17+)
  if midi_over_osc_vport == nil then
    print("Existing midi-over-osc vport not found")
    midi_over_osc_vport = max_index(midi.vports) + 1 -- global! todo: convert to local and kill
    debug_vport_17 = true -- debug to see if this gets tripped
  end
  print("Init: setting midi_over_osc_vport to " .. midi_over_osc_vport)  
  
  -- device id is always negative. I guess so it doesn't have to compete with physical devices
  midi_over_osc_id = min_index(midi.devices) - 1 -- global!
  print("Init: setting midi_over_osc_id to " .. midi_over_osc_id)

  midi = fake_midi    
	local old_init = init
	init = function()
	  old_init()
    old_osc_event = osc.event

  	function osc.event(path, args, from)
  	  print("OSC received")
  	  if path == "/midi-over-osc" then

        -- touching midi table now goes through a metatable which adds quite a bit of overhead. Need to maybe store the event function elsewhere to avoid this.
        
  		  -- if type(midi.vports[midi.devices[midi_over_osc_id].port].event) == "function" then
  		  --   midi.vports[midi_over_osc_vport].event(midi.to_data({type=args[1], note=args[2], vel=args[3], ch=args[4]}))
		    -- end
		    
		    --simpler, using vports var, but still touches midi 3 times per msg
		    if type(midi.vports[midi_over_osc_vport].event) == "function" then
  		    midi.vports[midi_over_osc_vport].event(midi.to_data({type=args[1], note=args[2], vel=args[3], ch=args[4]}))
		    end
		    
	    elseif old_osc_event ~= nil then 
    	  old_osc_event(path, args, from)
		  end
  	end
  	
  end
end)


mod.hook.register("script_post_cleanup", "midi-over-osc post cleanup", function()
	midi = fake_midi.real_midi
  osc.event = old_osc_event
end)