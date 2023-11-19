local mod = require 'core/mods'
local filepath = "/home/we/dust/data/cybermidi/"

-- lookup IP in registry, return ip_registry index
local function ip_lookup(ip)
  return(tab.key(cybermidi.ip_registry, ip))
end

local function read_prefs()
  prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    cybermidi.ip_registry = prefs.ip_registry -- registry of IPs
    cybermidi.ip_registry_index = prefs.ip_registry_index -- last selected registry index
  else
    cybermidi.ip_registry = {"127.0.0.1"}
    cybermidi.ip_registry_index = 1
  end
  print("CYBERMIDI: ----------------------")
  print("CYBERMIDI: ip_registry loaded:")
  tab.print(cybermidi.ip_registry)
  print("CYBERMIDI: ip_registry_index = " .. cybermidi.ip_registry_index)
  print("CYBERMIDI: ----------------------")
end
  
local function write_prefs()
  local filepath = "/home/we/dust/data/cybermidi/"
  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end
  prefs.ip_registry = cybermidi.ip_registry
  prefs.ip_registry_index = ip_lookup(cybermidi.ip) -- can just use direct value once established
  tab.save(prefs, filepath .. "prefs.data")
  print("table >> write: " .. filepath.."prefs.data")
end

function get_options(param)
  local options = params.params[params.lookup[param]].options
  return (options)
end

function ips()  -- debuggin' DELETE
  print(wifi.ip, cybermidi.ip, cybermidi.ip_registry[cybermidi.ip_registry_index], cybermidi.ip_registry_index)
end

function get_hostname()
  local result = util.os_capture("hostname")
  return result
end

local function get_subnet(ip)
  local lastdot = ip:match(".*()%.")
  return lastdot and ip:sub(1, lastdot) or ip
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

function ip_to_number(ip_string)
  local padded_seg = {}
  for segment in ip_string:gmatch("(%d+)") do
    table.insert(padded_seg, string.format("%03d", tonumber(segment)))
  end
  local concatenated = table.concat(padded_seg)
  return tonumber(concatenated)
end

function set_ip(from)
  local ip = cybermidi.ip_registry[params:get("cybermidi_dest")]
  print("CYBERMIDI: set_ip() called by " .. from .. ": setting IPs to " .. ip)
  cybermidi.ip = ip
  cybermidi.ip_registry_index = ip_lookup(cybermidi.ip)
end

-- Update "options" style param with new table of values
function update_options(param_id, options)  
  local param_index = params.lookup[param_id]
  local old_index = params:get(param_id)
  local old_string = params:string(param_id)
  local new_index = tab.key(options, old_string) or 1
  local new_string = options[new_index]
  
  params.params[param_index].options = options
  params.params[param_index].count = #options
  params:set(param_id, new_index)

  -- trigger param action in case index didn't change
  if (old_string ~= new_string) and (old_index == new_index) then
    params.params[param_index].action()
  end
end
          

mod.hook.register("script_pre_init", "cybermidi pre init", function() --todo system_post_startup
  cybermidi = {}  -- todo local (what about old_virtual though)
  read_prefs()
  cybermidi.ip = cybermidi.ip_registry[cybermidi.ip_registry_index]
  cybermidi.port = 10111
  print("CYBERMIDI: virtual midi port " .. (midi.devices[1].port or "not configured"))
  print("CYBERMIDI: Destination IP = " .. cybermidi.ip)
  
  -- issue. If user goes into mod menu and receives no registry responses, what do we do with ip_registry??
  
  -- cybermidi.ip_registry = {"127.0.0.1"}  -- todo what about retaining manual IPs

  -- init destination selector param
  if params.lookup["cybermidi_dest"] == nil then
    params:add_option("cybermidi_dest", "Destination", cybermidi.ip_registry, cybermidi.ip_registry_index)
    params:set_action("cybermidi_dest", function() set_ip("m.init action") end)
    params:hide("cybermidi_dest")
  end

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
			  if args[1] == "ping" then
			    local from = from[1]
			    print("CYBERMIDI: Pinged by " .. from)
			    if from ~= wifi.ip then -- don't respond with own IP. Will always provide "127.0.0.1"
			    -- for dev, allow passing of a fake IP rather than using args[1]
	        osc.send({from, cybermidi.port}, "/cybermidi", {"reg", wifi.ip, get_hostname()})
			    end
        
        --   -- pass along some fake IPs to test with
	       -- osc.send({from, cybermidi.port}, "/cybermidi", {"reg", "192.168.1.5", "host_c"})
	       -- osc.send({from, cybermidi.port}, "/cybermidi", {"reg", "192.168.1.111", "host_b"})
	       -- osc.send({from, cybermidi.port}, "/cybermidi", {"reg", "192.168.1.1", "host_a"})

			  elseif args[1] == "reg" then  -- register destination
			    -- local dest_ip = from[1] -- disabled for testing. remove 2nd arg and restore
			    local dest_ip = args[2]
			    
			    -- OK this is weird but there is an issue where a pinged Norns can respond to the broadcast OSC msg and respond with its hostname, but doesn't have a value for wifi.ip. Confirmed by logging into maiden where "wifi.ip" produces no response until I went into System>>WIFI
			    -- if issue reappears, maybe try wifi.connection:ip4()
			    if dest_ip == nil then
			      print("CYBERMIDI: RESPONDING DEVICE HAS NO IP ADDRESS. WTF?")
		      else
  			    local dest_hostname = args[3]

            cybermidi.new_entry = true
            print("CYBERMIDI: Destination available: " .. dest_ip, dest_hostname)
            
            if type(cybermidi.ip_registry) == "nil" then
              cybermidi.ip_registry = {"127.0.0.1"} -- todo global!
            end
            
            for i = 1, #cybermidi.ip_registry do
              if dest_ip == cybermidi.ip_registry[i] then -- todo ip+hostname
                cybermidi.new_entry = false
              end
            end
            
            if cybermidi.new_entry == true then
              table.insert(cybermidi.ip_registry, dest_ip)  -- todo something breaking here
              table.sort(cybermidi.ip_registry, function(a, b)
                return ip_to_number(a) < ip_to_number(b)
              end)
            end
            
            update_options("cybermidi_dest", cybermidi.ip_registry)
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
  write_prefs()
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
  screen.move(0,20)
  screen.text((wifi.ip or "No IP") .. " (" .. get_hostname() .. ")")

  screen.level(15)
  screen.move(0,40)
  screen.text("Destination")
  screen.move(127,40)
  -- screen.text_right(cybermidi.ip)
  screen.text_right(params:string("cybermidi_dest"))
  screen.update()
end

function m.init() -- on menu entry
  
  -- need to think on this a bit. Issue is that if we send a ping a no one responds... should we wipe everything in the ip_registry, let the current value stay there, etc..
  -- cybermidi.ip_registry = {"127.0.0.1"}

  -- big assumption here that we're on a LAN so we ping subnet's broadcast address
  -- todo: fallback for pinging 1-254 or something like that?
  osc.send({get_subnet(wifi.ip) .. 255, cybermidi.port}, "/cybermidi", {"ping"})
  -- todo set some sort of flag so we know how long to wait before wiping ip_registry?
end

function m.deinit() -- on menu exit
  write_prefs()
end

mod.menu.register(mod.this_name, m)