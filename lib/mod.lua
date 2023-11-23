local mod = require 'core/mods'
local filepath = "/home/we/dust/data/cybermidi/"

local function read_prefs()
  prefs = {}
  if util.file_exists(filepath.."prefs.data") then
    prefs = tab.load(filepath.."prefs.data")
    print('table >> read: ' .. filepath.."prefs.data")
    cybermidi.destination_type = prefs.destination_type
    cybermidi.lan_ip = prefs.lan_ip
    cybermidi.manual_ip = prefs.manual_ip
  else
    cybermidi.destination_type = "LAN"
    cybermidi.lan_ip = "127.0.0.1"
    cybermidi.manual_ip = "127.0.0.1"
  end
  if cybermidi.destination_type == "LAN" then
    cybermidi.ip = cybermidi.lan_ip
  else
    cybermidi.ip = cybermidi.manual_ip
  end
end
  
local function write_prefs(from)
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
end

local function parse_ip(ip)
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
  if cybermidi.destination_type == "LAN" then
    local ip = cybermidi.reg[cybermidi.reg_index].ip
    cybermidi.lan_ip = ip
    cybermidi.ip = ip
  else -- manual IP
    cybermidi.ip = cybermidi.manual_ip
  end
end
  
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

local function init_registries()
  cybermidi.reg = {}
  cybermidi.reg[1] = {ip = "127.0.0.1", name = "localhost"}
end

local function reindex_reg()  -- set new registry index after device discovery
  for i = 1, #cybermidi.reg do
    if cybermidi.lan_ip == cybermidi.reg[i].ip then
      cybermidi.reg_index = i
      break
    elseif i == #cybermidi.reg then 
      cybermidi.reg_index = 1 
    end
  end
  set_ip("reindex_reg")
end

-- this is ridiculous but I don't know how else to restore the table JFC
-- will also need to do this for live vport changes
local function restore_vport(index)
  print("CyberMIDI: Restoring MIDI functions on vport " .. index)
  
  local vport_path = midi.vports[index]
  function vport_path:note_on(note, vel, ch)
    self:send{type="note_on", note=note, vel=vel, ch=ch or 1}
  end
  function vport_path:note_off(note, vel, ch)
    self:send{type="note_off", note=note, vel=vel or 100, ch=ch or 1}
  end
  function vport_path:cc(cc, val, ch)
    self:send{type="cc", cc=cc, val=val, ch=ch or 1}
  end
  function vport_path:pitchbend(val, ch)
    self:send{type="pitchbend", val=val, ch=ch or 1}
  end
  function vport_path:key_pressure(note, val, ch)
    self:send{type="key_pressure", note=note, val=val, ch=ch or 1}
  end
  function vport_path:channel_pressure(val, ch)
    self:send{type="channel_pressure", val=val, ch=ch or 1}
  end
  function vport_path:program_change(val, ch)
    self:send{type="program_change", val=val, ch=ch or 1}
  end
  function vport_path:start()
    self:send{type="start"}
  end
  function vport_path:stop()
    self:send{type="stop"}
  end
  function vport_path:continue()
    self:send{type="continue"}
  end
  function vport_path:clock()
    self:send{type="clock"}
  end
  function vport_path:song_position(lsb, msb)
    self:send{type="song_position", lsb=lsb, msb=msb}
  end
  function vport_path:song_select(val)
    self:send{type="song_select", val=val}
  end
end


local function init_vport(index)
  print("CyberMIDI: Redefining MIDI functions on vport " .. index)
  local vport_path = midi.vports[index]

-- -- Currently we redefine each MIDI functions to bypass midi.send. If I could figure out a way to direct them to a redefined version of midi.send it'd be much tidier! 
-- function vport_path:send(data)
--   print("midi.send called")
--   if data.type then
--     print("send with data.type. d:")
--     print("type = " .. data.type)
--     local d = midi.to_data(data)  -- case changed
--     tab.print(d)
--     -- _norns.midi_send(self.dev, d)  -- replace with osc stuff
--   else
--     print("send raw")
--     -- _norns.midi_send(self.dev, data) -- replace with osc stuff
--   end
-- end  

  -- midi.vports[5]:send({type="note_on", note=44, vel=100, ch=1})
  
  
  function vport_path:note_on(note, vel, ch)
    print("CyberMIDI: processing note_on")
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="note_on", note=note, vel=vel, ch=ch}))
  end
  function vport_path:note_off(note, vel, ch)
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="note_off", note=note, vel=vel, ch=ch}))
  end
  function vport_path:cc(cc, val, ch) -- not passed to system pmap
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="cc", cc=cc, val=val, ch=ch}))
  end
  function vport_path:pitchbend(val, ch)
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="pitchbend", val=val, ch=ch}))
  end
  function vport_path:channel_pressure(val, ch)
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="channel_pressure", val=val, ch=ch}))
  end
  function vport_path:key_pressure(note, val, ch)
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="key_pressure", note=note, val=val, ch=ch}))
  end
  function vport_path:program_change(val, ch)
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="program_change", val=val, ch=ch}))
  end
  function vport_path:song_position(lsb, msb)
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="song_position", lsb=lsb, msb=msb}))
  end
  function vport_path:song_select(val)
    osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="song_select", val=val}))
  end  
    
  -- Realtime messages aren't processed by system clock on the receiving end. Virtual interface issue? 
  
  -- function vport_path:start()
  --   osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="start"})) -- 0xfa
  -- end  
  
  -- function vport_path:stop()
  --   osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="stop"}))  -- 0xfc
  -- end  
  
  -- function vport_path:continue()
  --   osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="continue"})) -- 0xfb
  -- end    
  
  -- function vport_path:clock()
  --   osc.send({cybermidi.ip, 10111}, "/cybermidi_msg", midi.to_data({type="clock"})) -- 0xf8
  -- end  
end


-- todo new script_post_init (requiring norns 231114)
mod.hook.register("script_pre_init", "cybermidi pre init", function() 
  wifi.update() -- addresses intermittent system bug resulting in nil wifi.ip
  cybermidi = {}
  read_prefs()
  print("CyberMIDI: Destination IP = " .. cybermidi.lan_ip)
  cybermidi.menu = 1
  cybermidi.octet_1, cybermidi.octet_2, cybermidi.octet_3, cybermidi.octet_4 = parse_ip(cybermidi.manual_ip)  
  -- auto-assign virtual interface to a port if needed
  if midi.devices[1].port == nil then
    for i = 1, 16 do
      if midi.vports[i].name == "none" then
        print("CyberMIDI: Assigning virtual midi interface to vport " .. i)
        midi.vports[i].name = "virtual"
        midi.update_devices()      
        break
      elseif i == 16 then
        print("CyberMIDI: All vports full! Make room in System>Devices>MIDI then restart")
      end
    end
  else
    print("CyberMIDI: Virtual midi interface found at vport " .. midi.devices[1].port)
  end
  
  -- for now we lock in the vport at mod launch and restore its functions on cleanup
  -- todo: allow live port switching, which will involve restoring functions and applying them
  cybermidi.vport_index = midi.devices[1].port
  init_vport(cybermidi.vport_index)
  
  
  print("CyberMIDI: Redefining midi.update_devices()")  -- debugging

  -- redefine midi.update_devices so when user changes vports we can redefine/restore functions
  -- todo restore?
  -- function Midi.update_devices()
  function midi.update_devices()
    print("CyberMIDI: Redefined midi.update_devices() called")  -- debugging
    -- reset vports for existing devices
    for _,device in pairs(midi.devices) do
      device.port = nil
    end
  
    -- connect available devices to vports
    for i=1,16 do
      midi.vports[i].device = nil
  
      for _, device in pairs(midi.devices) do
        if device.name == midi.vports[i].name then
          midi.vports[i].device = device
          device.port = i
        end
      end
    end
    
    -- Start of redefinition
    local function locate_vport(name)
      for i = 1, 16 do
        if midi.vports[i].name == name then
          return i
        elseif i == 16 then
          return nil
        end
      end
    end
    
    local new_vport_index = locate_vport("virtual")
    local old_vport_index = cybermidi.vport_index
    
    if new_vport_index ~= old_vport_index then
      print("CyberMIDI: Restoring previous virtual MIDI interface vport " .. old_vport_index)
      restore_vport(old_vport_index)  -- what about nil?
    end
    
    if new_vport_index ~= nil then
      print("CyberMIDI: Virtual MIDI interface set on vport " .. new_vport_index)
      init_vport(new_vport_index)
    else
      print("CyberMIDI: Virtual MIDI interface not found; assign in SYSTEM>>DEVICES>>MIDI")
    end
    
    cybermidi.vport_index = new_vport_index
    -- End of redefinition
          
    midi.update_connected_state()
  end
  
  

  local old_init = init
	init = function()
		old_init()
		cybermidi.old_osc_event = osc.event
		
		function osc.event(path, args, from)
			if path == "/cybermidi_msg" then
			  
			 -- todo: live check on vport here. would have to move vport midi functions
			 -- might be able to avoid extra check or error by defining dummy event handler?
	
			 -- could also redirect to event function saved elsewhere (update as needed?)
	     -- Maybe add virtual port logic to Midi.update_devices(): if virtual has changed, use 
	
			  if midi.vports[cybermidi.vport_index].event ~= nil then  -- Could just live with errors?
          midi.vports[cybermidi.vport_index].event(args)
			  end

		  elseif path == "/cybermidi_ping" then
		    local from = from[1]
		    print("CyberMIDI: Pinged by " .. from)
		    
		    if from ~= wifi.ip then -- don't respond with own IP. Localhost is available
        osc.send({from, 10111}, "/cybermidi_reg", {"reg", wifi.ip, get_hostname()})
		    end

		  elseif path == "/cybermidi_reg" then -- using own IP arg so we can fake IPs for dev purposes
		    local ip = args[2]
		    local name = args[3]

        for i = 1, #cybermidi.reg do
          if ip == cybermidi.reg[i].ip then
            break
          elseif i == #cybermidi.reg then
            table.insert(cybermidi.reg, {ip = ip, name = name})
            print("CyberMIDI: Destination registered: " .. ip .. " " .. name)
          end
        end
        
        table.sort(cybermidi.reg, function(a, b)
          return ip_to_number(a.ip) < ip_to_number(b.ip)
        end)
          
			elseif cybermidi.old_osc_event ~= nil then -- script osc passed through
				cybermidi.old_osc_event(path, args, from)
			end
		end
  	
	end

end)

mod.hook.register("script_post_cleanup", "cybermidi post cleanup", function()
  if cybermidi ~= nil then
    osc.event = cybermidi.old_osc_event -- restore og osc.event
    restore_vport(cybermidi.vport_index)
  end
end)

-- system mod menu for settings
local m = {}

function m.key(n, z)
  if z == 1 then
    if n == 2 then
      mod.menu.exit() 
    elseif n == 3 then
      if cybermidi.destination_type == "LAN" then
        m.init() -- refresh registry
        m.redraw()
      end
    end
  end
end

function m.enc(n, d)
  if n == 2 then
    local d = util.clamp(d, -1, 1)
    if cybermidi.destination_type == "LAN" then
      cybermidi.menu = util.clamp(cybermidi.menu + d, 1, 2)
    else -- IP
      cybermidi.menu = util.clamp(cybermidi.menu + d, 1, 5)
    end
  elseif n == 3 then
    if cybermidi.menu == 1 then -- LAN/Manual
      local d = util.clamp(d, -1, 1)
      local dest_type = cybermidi.destination_type == "LAN" and 1 or 2
      dest_type = util.clamp(dest_type + d, 1, 2)
      cybermidi.destination_type = dest_type == 1 and "LAN" or "Manual"
    else -- IP selector
      if cybermidi.destination_type == "LAN" then
        cybermidi.reg_index = util.clamp(cybermidi.reg_index + d, 1, #cybermidi.reg)
      else -- IP octet editor
        cybermidi["octet_" .. (cybermidi.menu - 1)] = util.wrap(cybermidi["octet_" .. (cybermidi.menu - 1)] + d, 0, 255)
        cybermidi.manual_ip = (cybermidi.octet_1 .. "." .. cybermidi.octet_2 .. "." .. cybermidi.octet_3 .. "." .. cybermidi.octet_4)
      end
    end
    set_ip("m.enc")
  end
  m.redraw()
end

function m.redraw()
  screen.clear()
  screen.level(4) -- Row 1: Menu
  screen.move(0,10)
  screen.text("MODS / CyberMIDI")
  screen.move(0,20)   -- Row 2: Device info
  screen.text(util.trim_string_to_width((wifi.ip or "No IP") .. " " .. get_hostname(), 127))
  screen.level(cybermidi.menu == 1 and 15 or 4)   -- Row 3.A: Destination type
  screen.move(0, 40)
  screen.text(cybermidi.destination_type)
  screen.text(" ")
  screen.level(cybermidi.menu > 1 and 15 or 4)  -- Row 3.B: IP selector
  if cybermidi.destination_type == "LAN" then 
    if cybermidi.state == "discovery" then
      screen.text("SEARCHING...")  
    else
      screen.text(util.trim_string_to_width(cybermidi.reg[cybermidi.reg_index].ip .. " " .. cybermidi.reg[cybermidi.reg_index].name, 110))
    end
  else -- IP
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
  osc.send({get_subnet(wifi.ip) .. 255, 10111}, "/cybermidi_ping", {"ping"}) -- ping subnet broadcast
  clock.run(
    function()
      clock.sleep(.5)-- 1/2s search window for LAN device discovery
      reindex_reg()
      cybermidi.state = "mod_menu"
      m.redraw()
    end
  )
end

function m.deinit() -- on menu exit
  cybermidi.state = "running"
  write_prefs("m.deinit")
end

mod.menu.register(mod.this_name, m)