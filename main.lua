isRunning = true
version = 1
 
Events = {}

local round = function(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

Current = {
  Document = nil,
  TextInput = nil,
  CursorPos = {1,1},
  CursorColour = colours.black,
  Selection = nil,
  Window = nil,
  HeaderText = '',
  StatusText = '',
  IrisState = '',
  StargateState = '',
  StatusColour = colours.grey,
  StatusScreen = true,
  PageControls = {},
  Fingerprint = nil,
  Page = '',
  Settings = {},
  Locked = false,
  Intern = false
}

DefaultSettings = {
  Whitelist = {},
  Addresses = {},
  Distance = 10,
  host =  true,
  password = '1337'
}

dofile("lib")

dofile("ui")


function ResetPage()
  Wireless.Responder = function()end
  if pocket or not Current.Settings.host then 
  
  else
    Stargate.Responder = function()end
  end
  pingTimer = nil
  Current.PageControls = nil
  Current.StatusScreen = false
  Current.PageControls = {}
  Current.TextInput = nil
end

function UpdateStargateStatus()
  Current.IrisState = Stargate.GetIrisState()
  local state, chevrons, direction = Stargate.GetStargateState()
  Current.StargateState = state
end

function ResetStatus()
  if pocket or not Current.Settings.host then 
    if not Wireless.Present() then
      SetText('Stargate Control', 'Add Wireless Modem to PDA', colours.red, true)
    else
      SetText('Stargate Control', 'Ready', colours.grey, true)
    end
  else
    if not Wireless.Present() then
      SetText('Stargate Control', ' Attach a Wireless Modem then reboot', colours.red, true)
      return
    end
    if not Stargate.Present() then
      SetText('Stargate Control', ' Attach a Stargate Interface then reboot', colours.red, true)
      return
    end
    UpdateStargateStatus()
    SetText('Stargate Control', 'Ready', colours.green)
  end
end

function HostStatusPage()
  ResetPage()
  Current.Page = 'HostStatus'
  Current.StatusScreen = true
  ResetStatus()
  
  table.insert(Current.PageControls, Button:Initialise(Drawing.Screen.Width - 6, Drawing.Screen.Height - 1, nil, nil, nil, nil, Quit, 'Quit', colours.black))
  table.insert(Current.PageControls, Button:Initialise(2, Drawing.Screen.Height - 1, nil, nil, nil, nil, HostSetupPage, 'Settings/Help', colours.black))

  Wireless.Responder = function(event, side, channel, replyChannel, message, distance)
    local msg = message.content
    if distance < Current.Settings.Distance then
      if channel == Wireless.Channels.GateRequest then
        if msg.version and msg.protocol == 'fingerprint' then
          if FingerprintIsOnWhitelist(msg.response) then
            Wireless.SendMessage(Wireless.Channels.GateRequestReply, {protocol = 'fingerprint', version = version, response = true} )
          else
            Wireless.SendMessage(Wireless.Channels.GateRequestReply, {protocol = 'fingerprint',version = version, response = false} )
          end
        elseif msg.protocol == 'stargate' then
          Stargate.HandleMessageWireless(message.messageID,msg)
        end
      elseif channel == Wireless.Channels.GateRequestReply then

      end
    end
  end
  Stargate.Responder = function(event, param, param2, param3, param4 )
    if event == 'sgIrisStateChange' then
      ResetStatus()
    elseif event == 'sgStargateStateChange' then
      ResetStatus()
    end
  end

  PingPocketComputers()
end

function HostSetupPage()
  ResetPage()
  Current.Page = 'HostSetup'
  AddHeader("Settings Page")
  table.insert(Current.PageControls, Button:Initialise(Drawing.Screen.Width - 6, Drawing.Screen.Height - 1, nil, nil, nil, nil, HostStatusPage, 'Save', colours.black))
  if not Current.Settings then
    Current.Settings = DefaultSettings
  end
  SaveSettings()  

  local distanceButtons = {}
  local function resetDistanceToggle(self)
    for i, v in ipairs(distanceButtons) do
      if v.Toggle ~= nil then
        v.Toggle = false
      end
    end
      if self.Text == 'Small' then
        Current.Settings.Distance = 10
      elseif self.Text == 'Normal' then
        Current.Settings.Distance = 15
      elseif self.Text == 'Far' then
        Current.Settings.Distance = 20
      end
    SaveSettings()
  end

  table.insert(Current.PageControls, Label:Initialise(23, 2, 'Opening Distance'))
  distanceButtons = {
    Button:Initialise(23, 4, nil, nil, nil, nil, resetDistanceToggle, 'Small', colours.black, false, colours.green),
    Button:Initialise(31, 4, nil, nil, nil, nil, resetDistanceToggle, 'Normal', colours.black, false, colours.green),
    Button:Initialise(40, 4, nil, nil, nil, nil, resetDistanceToggle, 'Far', colours.black, false, colours.green)
  }
    for i, v in ipairs(distanceButtons) do
      if v.Text == 'Small' and Current.Settings.Distance == 10 then
        v.Toggle = true
      elseif v.Text == 'Normal' and Current.Settings.Distance == 15 then
        v.Toggle = true
      elseif v.Text == 'Far' and Current.Settings.Distance == 20 then
        v.Toggle = true
      end
      table.insert(Current.PageControls, v)
    end

  table.insert(Current.PageControls, Label:Initialise(2, 10, 'Registered PDAs: '..#Current.Settings.Whitelist))
  table.insert(Current.PageControls, Button:Initialise(2, 12, nil, nil, nil, nil, function()Current.Settings.Whitelist = {}HostSetupPage()end, 'Unregister All', colours.black))

    
    table.insert(Current.PageControls, Label:Initialise(23, 6, 'Help', colours.black))
    local helpLines = {
      Label:Initialise(23, 8, 'To register a new PDA simply', colours.black),
      Label:Initialise(23, 9, 'place a Disk Drive next to', colours.black),
      Label:Initialise(23, 10, 'the computer, then put the', colours.black),
      Label:Initialise(23, 11, 'PDA in the Drive, it will', colours.black),
      Label:Initialise(23, 12, 'register automatically. If', colours.black),
      Label:Initialise(23, 13, 'it worked it will eject.', colours.black)
    }
    for i, v in ipairs(helpLines) do
      table.insert(Current.PageControls, v)
    end


  table.insert(Current.PageControls, Button:Initialise(2, 14, nil, nil, nil, nil, function()
      for i = 1, 6 do
        helpLines[i].TextColour = colours.green
      end
  end, 'Register New PDA', colours.black))
end

function AddHeader(label)
  if label == nil then
    label = "Label doesn't set!"
  end
  local x = math.ceil((Drawing.Screen.Width - #label) / 2) 
  table.insert(Current.PageControls, Label:Initialise(x, 1, label, colours.blue))
end

function PocketResetPage(value,label)
  ResetPage()
  Current.Page = value
  table.insert(Current.PageControls, Button:Initialise(Drawing.Screen.Width - 6, Drawing.Screen.Height - 1, nil, nil, nil, nil, Quit, 'Quit', colours.black))
  table.insert(Current.PageControls, Button:Initialise(2, Drawing.Screen.Height - 1, nil, nil, nil, nil, PocketHomePage, 'Menu', colours.black))

  AddHeader(label)
end

function PocketCallHome()
end

function PocketDailingPage(address)
  PocketResetPage("PocketDailingPage","Dailing Page")
  
  Draw()

  Stargate.Dail(address)


end

function PocketDailPage()
  PocketResetPage("PocketDailPage","Dail Page")

  table.insert(Current.PageControls, Label:Initialise(1, 3, 'Instant Dails', colours.blue))
  table.insert(Current.PageControls, Button:Initialise(Drawing.Screen.Width - 5, 3, nil, nil, nil, nil, nil, 'Add', colours.black))
  local lastI = 0
  for i,v in ipairs(Current.Settings.Addresses) do
    local dailing = function()
      PocketDailingPage(v[1])
    end
    table.insert(Current.PageControls, Button:Initialise(1, 4 + i, nil, nil, nil, nil, dailing, v[2], colours.black))
    lastI = i
  end
  table.insert(Current.PageControls, Label:Initialise(1, 6 + lastI, 'Maunal Dail', colours.blue))
end

function PocketIrisPage()
  PocketResetPage("PocketIrisPage","Iris Page")
  local close = function()
    Stargate.CloseIris()
  end
  local open = function()
    Stargate.OpenIris()
  end

  table.insert(Current.PageControls, Button:Initialise(2,3, nil, nil, nil, nil, close, 'Close', colours.black))
  table.insert(Current.PageControls, Button:Initialise(2,5, nil, nil, nil, nil, open, 'Open', colours.black))
end

function AddLabelValue(line,label,value)
  table.insert(Current.PageControls, Label:Initialise(1, line, label, colours.blue))
  table.insert(Current.PageControls, Label:Initialise(1+12, line, value, colours.blue))
end

function PocketStatePage()
  PocketResetPage("PocketStatePage","State Page")

  local locAddr = Stargate.GetLocalAddress()
  AddLabelValue(3,"Local:",locAddr)
  local remAddr = Stargate.GetRemoteAddress()
  AddLabelValue(3,"Remote:",remAddr)
  local state, chevrons, direction = Stargate.GetStargateState()
  AddLabelValue(3,"State:",state)
  AddLabelValue(3,"Engaged:",chevrons)
  AddLabelValue(3,"Direction:",direction)
  local energy = Stargate.GetEnergyAvailable()
  AddLabelValue(3,"Energy:",energy)
  local iris = Stargate.GetIrisState()
  AddLabelValue(3,"Iris:",iris)
end

function PocketHomePage()
  ResetPage()
  Current.Page = 'PocketHome'
  AddHeader("Home Page")

  table.insert(Current.PageControls, Button:Initialise(Drawing.Screen.Width - 6, Drawing.Screen.Height - 1, nil, nil, nil, nil, Quit, 'Quit', colours.black))
  table.insert(Current.PageControls, Button:Initialise(2, Drawing.Screen.Height - 1, nil, nil, nil, nil, os.reboot, 'Reboot', colours.black))

  if not Current.Intern then
    table.insert(Current.PageControls, Button:Initialise(2,3, nil, nil, nil, nil, PocketCallHome, 'Call Home', colours.black))
    table.insert(Current.PageControls, Button:Initialise(2,5, nil, nil, nil, nil, PocketDailPage, 'Dail', colours.black))
    table.insert(Current.PageControls, Button:Initialise(2,7, nil, nil, nil, nil, Stargate.Disconnect, 'Disconnect', colours.black))
  else
    table.insert(Current.PageControls, Button:Initialise(2,3, nil, nil, nil, nil, PocketDailPage, 'Dail', colours.black))
    table.insert(Current.PageControls, Button:Initialise(2,5, nil, nil, nil, nil, PocketIrisPage, 'Iris', colours.black))
    table.insert(Current.PageControls, Button:Initialise(2,7, nil, nil, nil, nil, PocketStatePage, 'State', colours.black))
    table.insert(Current.PageControls, Button:Initialise(2,9, nil, nil, nil, nil, Stargate.Disconnect, 'Disconnect', colours.black))
  end
end

function PocketLoginPage()
  ResetPage()
  Current.Page = 'PocketLogin'
  AddHeader("Login Page")
  
  table.insert(Current.PageControls, Label:Initialise(1, 6, 'Password:'))

  local change = function(key)
    if key == keys.enter then
      if Current.Settings.Password == Current.TextInput.Value then
        PocketHomePage()
      end
    end
  end

  textbox = TextBox:Initialise(10, 6, 10, nil, nil, nil, colours.white,colours.black,change,nil)
  Current.TextInput = textbox.TextInput
  table.insert(Current.PageControls, textbox)
  table.insert(Current.PageControls, Button:Initialise(Drawing.Screen.Width - 6, Drawing.Screen.Height - 1, nil, nil, nil, nil, Quit, 'Quit', colours.black))
  table.insert(Current.PageControls, Button:Initialise(2, Drawing.Screen.Height - 1, nil, nil, nil, nil, PocketStatusPage, 'Cancel', colours.black))
end

function PocketStatusPage()
  ResetPage()
  Current.Page = 'PocketStatus'
  Current.StatusScreen = true
  table.insert(Current.PageControls, Button:Initialise(Drawing.Screen.Width - 6, Drawing.Screen.Height - 1, nil, nil, nil, nil, Quit, 'Quit', colours.black))
  table.insert(Current.PageControls, Button:Initialise(2, Drawing.Screen.Height - 1, nil, nil, nil, nil, os.reboot, 'Reboot', colours.black))
  ResetStatus()

  Wireless.Responder = function(event, side, channel, replyChannel, message, distance)
    local msg = message.content
    if channel == Wireless.Channels.GatePing then
      if msg.version and msg.protocol == 'imap' then
        Wireless.SendMessage(replyChannel,{protocol = 'fingerprint',version = version, response = Current.Fingerprint}  , Wireless.Channels.GateRequestReply, nil, message.senderID)
      end
    elseif channel == Wireless.Channels.GateRequestReply then
      if msg.version and msg.protocol == 'fingerprint' then
        Current.Intern = msg.response
        PocketLoginPage()
        Draw()
      end
    end
  end
end

local textbox = nil
local textbox2 = nil
function PocketSetupPage()
  ResetPage()
  Current.Page = 'PocketSetup'
  --table.insert(Current.PageControls, Button:Initialise(Drawing.Screen.Width - 6, Drawing.Screen.Height - 1, nil, nil, nil, nil, PocketStatusPage, 'Save', colours.black))
  table.insert(Current.PageControls, Label:Initialise(9, 1, 'Setup Page', colours.blue))
  
  table.insert(Current.PageControls, Label:Initialise(1, 5, 'Password:'))
  table.insert(Current.PageControls, Label:Initialise(1, 6, 'Re-Password:'))

  local key1 = ""
  local change = function(key)
    if key == keys.enter then
      key1 = Current.TextInput.Value
      Current.TextInput = textbox2.TextInput
    end
  end

  local change2 = function(key)
    if key == keys.enter then
      local key2 = Current.TextInput.Value
      if key2 == key1 then
        Current.Settings.Password = key1
        SaveSettings()
        PocketStatusPage()
      end
    end
  end

  textbox = TextBox:Initialise(13, 5, 10, nil, nil, nil, colours.white,colours.black,change,nil)
  textbox2 = TextBox:Initialise(13, 6, 10, nil, nil, nil, colours.white,colours.black,change2,nil)
  Current.TextInput = textbox.TextInput
  table.insert(Current.PageControls, textbox)
  table.insert(Current.PageControls, textbox2)
end

function PocketInitialise()

  if not Wireless.Present() then
    PocketStatusPage()
    return
  end

  Wireless.Initialise()
  
  if fs.exists('.fingerprint') then
    local h = fs.open('.fingerprint', 'r')
    if h then
      Current.Fingerprint = h.readAll()
    else
      MakeFingerprint()
    end
    h.close()
  else
    MakeFingerprint()
  end

  if fs.exists('.settings') then
    PocketStatusPage()            
  else
    PocketSetupPage()
  end
end

function HostInitialise()
  if fs.exists('.settings') then
    HostStatusPage()               
  else

    HostSetupPage()
  end
end

function Initialise(arg)
  EventRegister('mouse_click', TryClick)
  EventRegister('mouse_drag', function(event, side, x, y)TryClick( event, side, x, y, true)end)
  EventRegister('terminate', function(event) error( "Terminated", 0 ) end)
  EventRegister('modem_message', Wireless.HandleMessage)
  EventRegister('timer', Timer)
  EventRegister('key', HandleKey)
  EventRegister('char', HandleKey)

  if fs.exists('.settings') then
    local h = fs.open('.settings', 'r')
    if h then
      Current.Settings = textutils.unserialize(h.readAll())
    end
    h.close()
  end

  if pocket or not Current.Settings.host then
  else
    EventRegister('disk', RegisterPDA)
    EventRegister('sgDialIn',Stargate.HandleMessage)
    EventRegister('sgDialOut',Stargate.HandleMessage)
    EventRegister('sgChevronEngaged',Stargate.HandleMessage)
    EventRegister('sgStargateStateChange',Stargate.HandleMessage)
    EventRegister('sgIrisStateChange',Stargate.HandleMessage)
    EventRegister('sgMessageReceived',Stargate.HandleMessage)
  end

  if pocket or not Current.Settings.host then
    PocketInitialise()
  else
    HostInitialise()
  end

  Draw()
  EventHandler()
end


if term.isColor and term.isColor() then
  local _, err = pcall(Initialise)
  if err then
    term.setCursorPos(1,1)
    term.setBackgroundColour(colours.black)
    term.setTextColour(colours.white)
    term.clear()
    print('Stargate Control has crashed')
    print('To maintain security, the computer will reboot.')
    print('If you are seeing this alot try turning off all Pocket Computers or reinstall.')
    print()
    print('Error:')
    printError(err)
    sleep(5)
    os.reboot()
  end
else
  print('GateControl requires an advanced (gold) computer or pocket computer.')
end