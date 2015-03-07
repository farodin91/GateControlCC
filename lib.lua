local getNames = peripheral.getNames or function()
  local tResults = {}
  for n,sSide in ipairs( rs.getSides() ) do
    if peripheral.isPresent( sSide ) then
      table.insert( tResults, sSide )
      local isWireless = false
      if not pcall(function()isWireless = peripheral.call(sSide, 'isWireless') end) then
        isWireless = true
      end     
      if peripheral.getType( sSide ) == "modem" and not isWireless then
        local tRemote = peripheral.call( sSide, "getNamesRemote" )
        for n,sName in ipairs( tRemote ) do
          table.insert( tResults, sName )
        end
      end
    end
  end
  return tResults
end

Peripheral = {
  GetPeripheral = function(_type)
    for i, p in ipairs(Peripheral.GetPeripherals()) do
      if p.Type == _type then
        return p
      end
    end
  end,
  Call = function(type, ...)
    local tArgs = {...}
    local p = Peripheral.GetPeripheral(type)
    peripheral.call(p.Side, unpack(tArgs))
  end,
  GetPeripherals = function(filterType)
    local peripherals = {}
    for i, side in ipairs(getNames()) do
      local name = peripheral.getType(side):gsub("^%l", string.upper)
      local code = string.upper(side:sub(1,1))
      if side:find('_') then
          code = side:sub(side:find('_')+1)
      end
      local dupe = false
      for i, v in ipairs(peripherals) do
        if v[1] == name .. ' ' .. code then
          dupe = true
        end
      end
      if not dupe then
        local _type = peripheral.getType(side)
        local isWireless = false
        if _type == 'modem' then
          if not pcall(function()isWireless = peripheral.call(sSide, 'isWireless') end) then
            isWireless = true
          end     
          if isWireless then
            _type = 'wireless_modem'
            name = 'W '..name
          end
        end
        if not filterType or _type == filterType then
          table.insert(peripherals, {Name = name:sub(1,8) .. ' '..code, Fullname = name .. ' ('..side:sub(1, 1):upper() .. side:sub(2, -1)..')', Side = side, Type = _type, Wireless = isWireless})
        end
      end
    end
    return peripherals
  end,
  PresentNamed = function(name)
    return peripheral.isPresent(name)
  end,
  CallType = function(type, ...)
    local tArgs = {...}
    local p = Peripheral.GetPeripheral(type)
    return peripheral.call(p.Side, unpack(tArgs))
  end,
  CallNamed = function(name, ...)
    local tArgs = {...}
    return peripheral.call(name, unpack(tArgs))
  end
}

function FingerprintIsOnWhitelist(fingerprint)
  if Current.Settings.Whitelist then
    for i, f in ipairs(Current.Settings.Whitelist) do
      if f == fingerprint then
        return true
      end
    end
  end
  return false
end

function SaveSettings()
  Current.Settings = Current.Settings or {}
  local h = fs.open('.settings', 'w')
  if h then
    h.write(textutils.serialize(Current.Settings))
  end
  h.close()      
end
 
function GenerateFingerprint()
  local str = ""
  for _ = 1, 256 do
    local char = math.random(32, 126)
    --if char == 96 then char = math.random(32, 95) end
    str = str .. string.char(char)
  end
  return str
end
 
function MakeFingerprint()
    local h = fs.open('.fingerprint', 'w')
    if h then
        h.write(GenerateFingerprint())
    end
    h.close()
    Current.Fingerprint = str
end

function RegisterPDA(event, drive)
  if disk.hasData(drive) then
    local _fs = fs
    local path = disk.getMountPath(drive)
    local addStartup = true
    if _fs.exists(path..'/System/') then
      path = path..'/System/'
      addStartup = false
    end
    local fingerprint = nil
    if _fs.exists(path..'/.fingerprint') then
      local h = _fs.open(path..'/.fingerprint', 'r')
      if h then
        local str = h.readAll()
        if #str == 256 then
          fingerprint = str
        end
      end
      h.close()
    end
    if not fingerprint then
      fingerprint = GenerateFingerprint()
      local h = _fs.open(path..'/.fingerprint', 'w')
      h.write(fingerprint)
      h.close()
      if addStartup then
        local h = fs.open('/startup', 'r')
        local startup = h.readAll()
        h.close()
        local h = _fs.open(path..'/startup', 'w')
        h.write(startup)
        h.close()
      end
    end
    if not FingerprintIsOnWhitelist(fingerprint) then
      table.insert(Current.Settings.Whitelist, fingerprint)
      SaveSettings()
    end
    disk.eject(drive)
  end
end

Wireless = {
  Channels = {
    GatePing = 4210,
    GateRequest = 4211,
    GateRequestReply = 4212,
  },

  isOpen = function(channel)
    return Peripheral.CallType('wireless_modem', 'isOpen', channel)
  end,

  Open = function(channel)
    if not Wireless.isOpen(channel) then
      Peripheral.CallType('wireless_modem', 'open', channel)
    end
  end,

  close = function(channel)
    Peripheral.CallType('wireless_modem', 'close', channel)
  end,

  closeAll = function()
    Peripheral.CallType('wireless_modem', 'closeAll')
  end,

  transmit = function(channel, replyChannel, message)
    Peripheral.CallType('wireless_modem', 'transmit', channel, replyChannel, textutils.serialize(message))
  end,

  Present = function()
    if Peripheral.GetPeripheral('wireless_modem') == nil then
      return false
    else
      return true
    end
  end,

  FormatMessage = function(message, messageID, destinationID)
    return {
      content = textutils.serialize(message),
      senderID = os.getComputerID(),
      senderName = os.getComputerLabel(),
      channel = channel,
      replyChannel = reply,
      messageID = messageID or math.random(10000),
      destinationID = destinationID
    }
  end,

  Timeout = function(func, time)
    time = time or 1
    parallel.waitForAny(func, function()
      sleep(time)
      --log('Timeout!'..time)
    end)
  end,

  RecieveMessage = function(_channel, messageID, timeout)
    Wireless.Open(_channel)
    local done = false
    local event, side, channel, replyChannel, message = nil
    Wireless.Timeout(function()
      while not done do
        event, side, channel, replyChannel, message = os.pullEvent('modem_message')
        if channel ~= _channel then
          event, side, channel, replyChannel, message = nil
        else
          message = textutils.unserialize(message)
          message.content = textutils.unserialize(message.content)
          if messageID and messageID ~= message.messageID or (message.destinationID ~= nil and message.destinationID ~= os.getComputerID()) then
            event, side, channel, replyChannel, message = nil
          else
            done = true
          end
        end
      end
    end,
    timeout)
    return event, side, channel, replyChannel, message
  end,

  Initialise = function()
    if Wireless.Present() then
      for i, c in pairs(Wireless.Channels) do
        Wireless.Open(c)
      end
    end
  end,

  HandleMessage = function(event, side, channel, replyChannel, message, distance)
    message = textutils.unserialize(message)
    message.content = textutils.unserialize(message.content)

    if channel == Wireless.Channels.Ping then
      if message.content == 'Ping!' then
        SendMessage(replyChannel, 'Pong!', nil, message.messageID)
      end
    elseif message.destinationID ~= nil and message.destinationID ~= os.getComputerID() then
    elseif Wireless.Responder then
      Wireless.Responder(event, side, channel, replyChannel, message, distance)
    end
  end,

  SendMessage = function(channel, message, reply, messageID, destinationID)
    reply = reply or channel + 1
    Wireless.Open(channel)
    Wireless.Open(reply)
    local _message = Wireless.FormatMessage(message, messageID, destinationID)
    Wireless.transmit(channel, reply, _message)
    return _message
  end,

  Ping = function()
    local message = SendMessage(Channels.Ping, 'Ping!', Channels.PingReply)
    RecieveMessage(Channels.PingReply, message.messageID)
  end
}

local ignoreNextChar = false
function HandleKey(...)
  local args = {...}
  local event = args[1]
  local keychar = args[2]
  --[[
                                              --Mac left command character
  if event == 'key' and keychar == keys.leftCtrl or keychar == keys.rightCtrl or keychar == 219 then
    isControlPushed = true
    controlPushedTimer = os.startTimer(0.5)
  elseif isControlPushed then
    if event == 'key' then
      if CheckKeyboardShortcut(keychar) then
        isControlPushed = false
        ignoreNextChar = true
      end
    end
  elseif ignoreNextChar then
    ignoreNextChar = false
  else
  ]]--
  if Current.TextInput then
    if event == 'char' then
      Current.TextInput:Char(keychar)
    elseif event == 'key' then
      Current.TextInput:Key(keychar)
    end
  end
end

local statusResetTimer = nil
function SetText(header, status, colour, isReset)
  if header then
    Current.HeaderText = header
  end
  if status then
    Current.StatusText = status
  end
  if colour then
    Current.StatusColour = colour
  end
  Draw()
  if not isReset then
    statusResetTimer = os.startTimer(2)
  end
end

function EventRegister(event, func)
    if not Events[event] then
        Events[event] = {}
    end
 
    table.insert(Events[event], func)
end

function EventHandler()
    while isRunning do
        local event, arg1, arg2, arg3, arg4, arg5, arg6 = os.pullEventRaw()
        if Events[event] then
            for i, e in ipairs(Events[event]) do
                e(event, arg1, arg2, arg3, arg4, arg5, arg6)
            end
        end
    end
end


local pingTimer = nil
function PingPocketComputers()
  Wireless.SendMessage(Wireless.Channels.GatePing, {protocol = 'imap',version = version, response = 'Ping!'} , Wireless.Channels.GateRequest)
  pingTimer = os.startTimer(0.5)
end

function Timer(event, timer)
  if timer == pingTimer then
    PingPocketComputers()
  elseif timer == statusResetTimer then
    ResetStatus()
  end
end

function Quit()
    isRunning = false
    term.setCursorPos(1,1)
    term.setBackgroundColour(colours.black)
    term.setTextColour(colours.white)
    term.clear()
end

Stargate = {
  label = 'stargate',
  HandleMessage = function(type, ...)
    local tArgs = {...}
    if Stargate.Responder then
      Stargate.Responder(type,unpack(tArgs))
    end
  end,
  
  Present = function()
    if pocket or not Current.Settings.host then
      return false
    else
      if Peripheral.GetPeripheral(Stargate.label) == nil then
        return false
      else
        return true
      end
    end
  end,

  HandleMessageWireless = function(id,message)
    if message.protocol == 'stargate' and message.version >= 1 then
      local f = Stargate[message.response.action]
      local ok,result = pcall(f,message.response.content)
      Wireless.SendMessage(Wireless.Channels.GateRequestReply,{protocol = 'stargate',version = version, response = {action=message.response.action,ok=ok,result=result}},nil,id)
    end
  end,

  RecieveMessage = function(id)
    local event, side, channel, replyChannel, message = Wireless.RecieveMessage(Wireless.Channels.GateRequestReply,id,5)
    if message then
      local content =  message.content
      if content == nil then 
        return nil
      elseif content.protocol == 'stargate' and content.version >= 1 then
        return content.response.result
      end 
    end
    return nil
  end,

  SendMessage = function(action,arg)
    local msg = nil
    if arg == nil then
      msg = Wireless.SendMessage(Wireless.Channels.GateRequest,{protocol = 'stargate',version = version, response = {action=action}},Wireless.Channels.GateRequestReply)
    else
      msg = Wireless.SendMessage(Wireless.Channels.GateRequest,{protocol = 'stargate',version = version, response = {action=action,content=arg}},Wireless.Channels.GateRequestReply)
    end
    return msg.messageID
  end,
  
  OpenIris = function()
    if pocket or not Current.Settings.host then
      local id = Stargate.SendMessage('OpenIris')
      return Stargate.RecieveMessage(id)
    else
      Peripheral.CallType(Stargate.label, 'openIris')
    end
  end,

  CloseIris = function()
    if pocket or not Current.Settings.host then
      local id = Stargate.SendMessage('CloseIris')
      return Stargate.RecieveMessage(id)
    else
      Peripheral.CallType(Stargate.label, 'closeIris')
    end
  end,

  GetIrisState = function()
    if pocket or not Current.Settings.host then
      local id = Stargate.SendMessage('GetIrisState')
      return Stargate.RecieveMessage(id)
    else
      return Peripheral.CallType(Stargate.label, 'irisState')
    end
  end,
  
  GetRemoteAddress = function()
    if pocket or not Current.Settings.host then
      local id = Stargate.SendMessage('GetRemoteAddress')
      return Stargate.RecieveMessage(id)
    else
      return Peripheral.CallType(Stargate.label, 'remoteAddress')
    end
  end,
  
  GetLocalAddress = function()
    if pocket or not Current.Settings.host then
      local id = Stargate.SendMessage('GetLocalAddress')
      return Stargate.RecieveMessage(id)
    else
      return Peripheral.CallType(Stargate.label, 'localAddress')
    end
  end,

  GetStargateState = function()
    if pocket or not Current.Settings.host then
      return "Soon","Soon","Soon"
    else
      return Peripheral.CallType(Stargate.label, 'stargateState')
    end
  end,
  
  GetEnergyAvailable = function()
    if pocket or not Current.Settings.host then
      return "Soon"
    else
      return Peripheral.CallType(Stargate.label, 'energyAvailable')
    end
  end,

  Disconnect = function()
    if pocket or not Current.Settings.host then
      local id = Stargate.SendMessage('Disconnect')
      return Stargate.RecieveMessage(id)

    else
      return Peripheral.CallType(Stargate.label, 'disconnect')
    end
  end,

  Dail = function(address)
    if pocket or not Current.Settings.host then
      local id = Stargate.SendMessage('Dail',address)
      return Stargate.RecieveMessage(id)
    else
      return Peripheral.CallType(Stargate.label, 'dail', address)
    end
  end,
}