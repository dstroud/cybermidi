local mod = require 'core/mods'

local filepath = "/home/we/dust/data/cybermidi/"

function get_options(param)
  local options = params.params[params.lookup[param]].options
  return (options)
end

function get_host_id(ip)
  local lastdot = ip:match(".*()%.")
  if lastdot then
    local id_string = ip:sub(lastdot + 1)
    return tonumber(id_string)
  else
    return nil
  end
end

function select_ip()
  local ip = params:string("cybermidi_dest")
  print("setting IPs to " .. ip)
  cybermidi.ip = ip
  last_ip = ip  -- why is this even a thing?
end

-- Function to compare IP host for sorting
local function compare(a, b)
  local a = get_host_id(a)
  local b = get_host_id(b)
  return a < b
end

local function read_prefs()
    -- print("DEBUG: read_prefs()")
  prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    -- destinations = prefs.destinations -- todo global!
    last_ip = prefs.last_ip or wifi.ip -- todo global!
  else
    -- voices = 4 --default # of voices
    destinations = {}
    table.insert(destinations, wifi.ip)
    last_ip = last_ip or wifi.ip -- wag
  end
end
  
local function write_prefs()
  local filepath = "/home/we/dust/data/cybermidi/"
  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end
  -- prefs.voices = voices
  prefs.destinations = destinations
  prefs.last_ip = cybermidi.ip  -- wag
  tab.save(prefs, filepath .. "prefs.data")
  print("table >> write: " .. filepath.."prefs.data")
end

mod.hook.register("script_pre_init", "cybermidi pre init", function() --todo system_post_startup
  
  cybermidi = {}  -- todo local (what about old_virtual though)
  cybermidi.ip = wifi.ip -- todo load last_ip
  cybermidi.port = 10111
  print("CYBERMIDI: IP = " .. cybermidi.ip)
  print("CYBERMIDI: virtual midi port " .. (midi.devices[1].port or "not configured"))
  
  read_prefs() -- wag on placement
  destinations = {}  -- global!
  table.insert(destinations, wifi.ip)
  
  midi_fn = {}  -- todo p0 local 
  function midi_fn:note_on(note, vel, ch)
    osc.send({cybermidi.ip, cybermidi.port}, "/cybermidi", {"note_on", note, vel or 100, ch or 1})
  end
  function midi_fn:note_off(note, vel, ch)
    osc.send({cybermidi.ip, cybermidi.port}, "/cybermidi", {"note_off", note, vel or 100, ch or 1})
  end

  -- todo handle nil/unconfigured vport- self-add?
  -- still needs to handle nils in case all ports are filld up, however
  local vport_id = midi.devices[1].port -- todo what if port changes mid-session
  -- cybermidi.old_virtual = midi.vports[vport_id] -- not sure if we need to restore this, but just in case
  
  -- todo better way to load functions. what if functions are omitted?
  -- for k, v in ipairs(midi_fn) do
  midi.vports[vport_id].note_on = midi_fn.note_on
  midi.vports[vport_id].note_off = midi_fn.note_off

  local old_init = init
	init = function()
	  
		old_init()
		old_osc_event = osc.event
		
		function osc.event(path, args, from)
			print("CYBERMIDI: OSC received")
			if path == "/cybermidi" then
			  if args[1] == "hello" then
			   -- local fromargs[2]
			   --print('from:')
			   --tab.print(from)
			    print("Pinged by " .. from[1])  -- can get from "from"
	        osc.send({from[1], cybermidi.port}, "/cybermidi", {"dest", wifi.ip}) -- for debuggining, allow passing of a fake IP rather than using args[1]

        --   -- pass along some dummy IPs to test iwth
	       -- osc.send({from[1], cybermidi.port}, "/cybermidi", {"dest", "192.168.1.111"})
	       -- osc.send({from[1], cybermidi.port}, "/cybermidi", {"dest", "192.168.1.1"})
	       -- osc.send({from[1], cybermidi.port}, "/cybermidi", {"dest", "192.168.1.5"})

			  elseif args[1] == "dest" then
			   -- local dest_ip = from[1] -- disabled for testing. remove 2nd arg and restore
			   local dest_ip = args[2]
          cybermidi.new_entry = true
          print("Destination available: " .. dest_ip)
          
          if type(destinations) == "nil" then
            destinations = {} -- to doglobal!
          end
          
          for i = 1, #destinations do
            if dest_ip  == destinations[i] then
              cybermidi.new_entry = false
            end
          end
          
          if cybermidi.new_entry == true then
            print("inserting des_ip into destinations")
            table.insert(destinations, dest_ip)
            table.sort(destinations, compare)
          end
          
          -- update destination selector param
          if params.lookup["cybermidi_dest"] == nil then
            print("creating param")
            params:add_option("cybermidi_dest", "Destination", destinations, 1)
            params:set_action("cybermidi_dest", function() select_ip() end)
            params:hide("cybermidi_dest")
          else
            print("updating param options")
            local val = last_ip -- params:string("cybermidi_dest")
            print("prev param val = " .. (val or "nil"))
            
            -- dummy msg to create additional destinations for testing
            -- osc.send({"192.168.1.3", cybermidi.port}, "/cybermidi", {"dest", "192.168.1.111"})
            params.params[params.lookup["cybermidi_dest"]].options = destinations
            params.params[params.lookup["cybermidi_dest"]].count = #destinations
            
            print("--------------------")
            print("options/destinations:")
            -- tab.print(params.params[params.lookup["cybermidi_dest"]].options)
            tab.print(destinations)

            -- THIS IS FUCKING UP
            local index = tab.key(destinations, val) or 1
            print("Setting param to index #" .. (index or "nil") .. ", " .. params.params[params.lookup["cybermidi_dest"]].options[index])

            params:set("cybermidi_dest", index)
            print("--------------------")
            
            -- manually trigger in case .options update resulted in new string values without triggering action
            print("manual action: setting cybermidi.ip to " .. params:string("cybermidi_dest"))
            select_ip()
          end       
          
				elseif type(midi.vports[vport_id].event) == "function" then -- .connected??
					midi.vports[vport_id].event(midi.to_data({type=args[1], note=args[2], vel=args[3], ch=args[4]}))
				end
			elseif old_osc_event ~= nil then 
				old_osc_event(path, args, from)
			end
		end
  	
	end

end)

mod.hook.register("script_post_cleanup", "cybermidi post cleanup", function() -- todo system_pre_shutdown
  osc.event = old_osc_event
  -- midi.vports[midi.devices[1].port] = cybermidi.old_virtual -- just in case??
end)

-- system mod menu for settings
local m = {}

function m.key(n, z)
  if n == 2 and z == 1 then
    mod.menu.exit() 
  end
end

function m.enc(n, d)
  if n == 3 then --voices = util.clamp(voices + d, 1, 4) 
    params:delta("cybermidi_dest", d)
    mod.menu.redraw() -- limit?
  end
end

function m.redraw()
  screen.clear()
  screen.level(4)
  screen.move(0,10)
  screen.text("MODS / CYBERMIDI")
  screen.level(15)
  screen.move(0,30)
  screen.text("Destination")
  screen.move(127,30)
  -- screen.text_right(cybermidi.ip)
  screen.text_right(params:string("cybermidi_dest"))
  screen.update()
end

function m.init() -- on menu entry
  -- print("MOD MENU INIT")
  read_prefs()  -- loads last_ip
  
  -- wipe any ip destinations before refresh.
  destinations = {} -- IMPORTANT: Disabled for debugging since we're adding fake IPs
  
  local function get_subnet(ip)
    local lastdot = ip:match(".*()%.")
    return lastdot and ip:sub(1, lastdot) or ip
  end
  
  -- todo handle nil ip
  local ip = wifi.ip
  local subnet =  get_subnet(ip)
  -- print("subnet = " .. (subnet or "nil"))
  
  local host = 255  -- can also zap 1-254 lol
  local dest_ip = subnet .. host
  osc.send({dest_ip, cybermidi.port}, "/cybermidi", {"hello"})
  
  -- init param with last_ip value
  if params.lookup["cybermidi_dest"] == nil then
    params:add_option("cybermidi_dest", "Destination", {last_ip}, 1)
    params:set_action("cybermidi_dest", function() select_ip() end)
    params:hide("cybermidi_dest")
  end

end

function m.deinit() -- on menu exit
  write_prefs()
end

mod.menu.register(mod.this_name, m)