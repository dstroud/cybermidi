local mod = require 'core/mods'
local filepath = "/home/we/dust/data/cybermidi/"

function parse_ip(ip) -- make local
  local octets = {}
  for octet in ip:gmatch("(%d+)") do
    table.insert(octets, tonumber(octet))
  end
  return table.unpack(octets)
end

local function get_hostname()
  local result = util.os_capture("hostname")
  return result
end

local function read_prefs()
  prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    cybermidi.destination_type = prefs.destination_type -- last destination (LAN/manual) index
    cybermidi.lan_ip = prefs.lan_ip
    cybermidi.manual_ip = prefs.manual_ip
  else
    cybermidi.destination_type = "LAN IP"
    cybermidi.lan_ip = "127.0.0.1"
    cybermidi.manual_ip = "127.0.0.1"
  end
  if cybermidi.destination_type == "LAN IP" then
    cybermidi.ip = cybermidi.lan_ip
  else
    cybermidi.ip = cybermidi.manual_ip
  end
end
  
local function write_prefs(from)
-- if cybermidi ~= nil then -- todo revisit after changing hooks
  print("write_prefs called from " .. from)
  local filepath = "/home/we/dust/data/cybermidi/"
  local prefs = {}
  if util.file_exists(filepath) == false then
    util.make_dir(filepath)
  end
  prefs.destination_type = cybermidi.destination_type
  prefs.lan_ip = cybermidi.lan_ip
  prefs.manual_ip = cybermidi.manual_ip
  tab.save(prefs, filepath .. "prefs.data")
  print("table >> write: " .. filepath.."prefs.data")
-- end
end

function get_options(param) -- debuggin' DELETE
  local options = params.params[params.lookup[param]].options
  return (options)
end

local function get_subnet(ip)
  local lastdot = ip:match(".*()%.")
  return lastdot and ip:sub(1, lastdot) or ip
end

local function get_host_id(ip)
  local lastdot = ip:match(".*()%.")
  if lastdot then
    local id_string = ip:sub(lastdot + 1)
    return tonumber(id_string)
  else
    return nil
  end
end

local function ip_to_number(ip_string)
  local padded_seg = {}
  for segment in ip_string:gmatch("(%d+)") do
    table.insert(padded_seg, string.format("%03d", tonumber(segment)))
  end
  local concatenated = table.concat(padded_seg)
  return tonumber(concatenated)
end

local function set_ip(from)
  if cybermidi.destination_type == "LAN IP" then
    local ip = cybermidi.reg[cybermidi.reg_index].ip
    cybermidi.lan_ip = ip
    cybermidi.ip = ip
  else -- manual IP
    cybermidi.ip = cybermidi.manual_ip
  end
end
  
local function init_registries()
  cybermidi.reg = {}
  cybermidi.reg[1] = {ip = "127.0.0.1", name = "norns"}
end

-- set new table index after registry has been updated with new devices
function reindex_registry()
  for i = 1, #cybermidi.reg do
    if cybermidi.lan_ip == cybermidi.reg[i].ip then
      cybermidi.reg_index = i
      break
    elseif i == #cybermidi.reg then 
      cybermidi.reg_index = 1 
    end
  end
  set_ip("reindex_registry")
end

-- todo system_post_startup and can then use script_pre_init or the new script_post_init (requiring norns 231114)
mod.hook.register("script_pre_init", "cybermidi pre init", function() 
  wifi.update() -- attempt to address intermittent system nil wifi.ip bug
  
  -- debug DELETE
  debug_a = true
  debug_b = true
  debug_c = true
        
  cybermidi = {}  -- todo local (what about old_virtual though)
  read_prefs()
  cybermidi.menu = 1
  cybermidi.octet_1, cybermidi.octet_2, cybermidi.octet_3, cybermidi.octet_4 = parse_ip(cybermidi.manual_ip)

  print("CYBERMIDI: virtual midi port " .. (midi.devices[1].port or "not configured"))
  print("CYBERMIDI: Destination IP = " .. cybermidi.lan_ip)

  midi_fn = {}  -- todo p0 local 
  function midi_fn:note_on(note, vel, ch)
    osc.send({cybermidi.ip, 10111}, "/cybermidi", {"note_on", note, vel or 100, ch or 1})
  end
  function midi_fn:note_off(note, vel, ch)
    osc.send({cybermidi.ip, 10111}, "/cybermidi", {"note_off", note, vel or 100, ch or 1})
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
		-- 	print("CYBERMIDI: OSC received")
			if path == "/cybermidi" then
			  if args[1] == "ping" then
			    local from = from[1]
			    print("CYBERMIDI: Pinged by " .. from)
			    
			    if from ~= wifi.ip then -- don't respond with own IP. Mod always offers "127.0.0.1"
			    -- for dev, allow passing of a fake IP rather than using args[1]
	        osc.send({from, 10111}, "/cybermidi", {"reg", wifi.ip, get_hostname()})
			    end
        
        -- pass along some fake IPs to test with
          if debug_c == true then
  	        osc.send({from, 10111}, "/cybermidi", {"reg", "192.168.1.111", "host_c"})
          end
          if debug_b == true then
  	        osc.send({from, 10111}, "/cybermidi", {"reg", "192.168.1.5", "host_b"})
          end
          if debug_a == true then
  	        osc.send({from, 10111}, "/cybermidi", {"reg", "192.168.1.1", "host_a"})
          end

			  elseif args[1] == "reg" then  -- register ip and hostname
			    -- local dest_ip = from[1] -- disabled for testing. remove 2nd arg and restore
			    local ip = args[2]
			    local name = args[3]
          print("CYBERMIDI: Destination registered: " .. ip .. " " .. name)

          for i = 1, #cybermidi.reg do
            if ip == cybermidi.reg[i].ip then
              break
            elseif i == #cybermidi.reg then
              table.insert(cybermidi.reg, {ip = ip, name = name})
            end
          end
          
          table.sort(cybermidi.reg, function(a, b)
            return ip_to_number(a.ip) < ip_to_number(b.ip)
          end)
            
				elseif type(midi.vports[vport_id].event) == "function" then -- todo: this feels bad
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
  if z == 1 then
    if n == 2 then
      mod.menu.exit() 
    elseif n == 3 then
      if cybermidi.destination_type == "LAN IP" then
        m.init() -- refresh registry
        m.redraw()
      end
    end
  end
end

function m.enc(n, d)
  if n == 2 then
    local d = util.clamp(d, -1, 1)
    if cybermidi.destination_type == "LAN IP" then
      cybermidi.menu = util.clamp(cybermidi.menu + d, 1, 2)
    else -- manual IP
      cybermidi.menu = util.clamp(cybermidi.menu + d, 1, 5)
    end
  elseif n == 3 then
    -- may want to flip logic order
    if cybermidi.menu == 1 then -- LAN/Manual
      local d = util.clamp(d, -1, 1)
      
      -- kinda sucks
      if cybermidi.destination_type == "LAN IP" and d == 1 then
        cybermidi.destination_type = "manual IP"
        set_ip("manual IP switch")
      elseif cybermidi.destination_type == "manual IP" and d == -1 then
        cybermidi.destination_type = "LAN IP"
        set_ip("LAN IP switch")
      end
      
    else -- IP selector
      if cybermidi.destination_type == "LAN IP" then
        cybermidi.reg_index = util.clamp(cybermidi.reg_index + d, 1, #cybermidi.reg)
        set_ip("m.enc")
      else -- manual IP octet editor
        cybermidi["octet_" .. (cybermidi.menu - 1)] = util.wrap(cybermidi["octet_" .. (cybermidi.menu - 1)] + d, 0, 255)
        cybermidi.manual_ip = (cybermidi.octet_1 .. "." .. cybermidi.octet_2 .. "." .. cybermidi.octet_3 .. "." .. cybermidi.octet_4)
        set_ip("IP octet editor")
      end
    end
  end
  m.redraw()
end

function m.redraw()
  -- Row 1: Menu
  screen.clear()
  screen.level(4)
  
  -- Row 2: Device info
  screen.move(0,10)
  screen.text("MODS / CYBERMIDI")
  screen.move(0,20)
  screen.text(util.trim_string_to_width((wifi.ip or "No IP") .. " " .. get_hostname(), 127))

  -- Row 4: LAN destination selector
  screen.level(cybermidi.menu == 1 and 15 or 4)
  screen.move(0, 40)
  screen.text("Send to: ")
  screen.text(cybermidi.destination_type)

  -- Row 5: IP selector
  screen.level(cybermidi.menu > 1 and 15 or 4)
  screen.move(0, 50)
  screen.text("IP: ")
  if cybermidi.destination_type == "LAN IP" then 
    if cybermidi.state == "discovery" then
      screen.text("SEARCHING...")  
    else
      -- screen.text(util.trim_string_to_width(params:string("cybermidi_lan_ip"), 112))
      screen.text(util.trim_string_to_width(cybermidi.reg[cybermidi.reg_index].ip .. " " .. cybermidi.reg[cybermidi.reg_index].name, 112))
    end
  else -- manual IP
    for i = 1, 4 do
      screen.level(cybermidi.menu == 1 and 4 or (cybermidi.menu - 1) == i and 15 or 4)
      screen.text(cybermidi["octet_" .. i])
      screen.level(4)
      if i < 4 then screen.text(".") end
    end
  end
  screen.update()
end

function m.init() -- on menu entry
  cybermidi.state = "discovery"
  init_registries()
  osc.send({get_subnet(wifi.ip) .. 255, 10111}, "/cybermidi", {"ping"}) -- ping subnet broadcast
  clock.run(
    function()
      clock.sleep(.5)-- search window for LAN device discovery
      reindex_registry()
      cybermidi.state = "mod_menu"
      m.redraw()
    end
  )
end

function m.deinit() -- on menu exit
  cybermidi.state = "running"
  print("CYBERMIDI: Exiting menu with cybermidi.state " .. tostring(cybermidi.state))
  write_prefs("m.deinit") -- saves only the most recent state
end

mod.menu.register(mod.this_name, m)