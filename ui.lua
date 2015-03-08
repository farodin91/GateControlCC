local _w, _h = term.getSize()

local round = function(num, idp)
        local mult = 10^(idp or 0)
        return math.floor(num * mult + 0.5) / mult
end

function OrderSelection()
  if Current.Selection then
    if Current.Selection[1]<=Current.Selection[2]then
      return Current.Selection
    else
      return{Current.Selection[2],Current.Selection[1]}
    end
  end
end

function FindColours(e)
  local t,e=e:gsub('['..string.char(14)..'-'..string.char(29)..']','')
  return e
end

Drawing = {
  
  Screen = {
    Width = _w,
    Height = _h
  },

  DrawCharacters = function (x, y, characters, textColour,bgColour)
    Drawing.WriteStringToBuffer(x, y, characters, textColour, bgColour)
  end,
  
  DrawBlankArea = function (x, y, w, h, colour)
    Drawing.DrawArea (x, y, w, h, " ", 1, colour)
  end,

  DrawArea = function (x, y, w, h, character, textColour, bgColour)
    --width must be greater than 1, other wise we get a stack overflow
    if w < 0 then
      w = w * -1
    elseif w == 0 then
      w = 1
    end

    for ix = 1, w do
      local currX = x + ix - 1
      for iy = 1, h do
        local currY = y + iy - 1
        Drawing.WriteToBuffer(currX, currY, character, textColour, bgColour)
      end
    end
  end,

  DrawImage = function(_x,_y,tImage, w, h)
    if tImage then
      for y = 1, h do
        if not tImage[y] then
          break
        end
        for x = 1, w do
          if not tImage[y][x] then
            break
          end
          local bgColour = tImage[y][x]
                local textColour = tImage.textcol[y][x] or colours.white
                local char = tImage.text[y][x]
                Drawing.WriteToBuffer(x+_x-1, y+_y-1, char, textColour, bgColour)
        end
      end
    elseif w and h then
      Drawing.DrawBlankArea(x, y, w, h, colours.green)
    end
  end,
  --using .nft
  LoadImage = function(path)
    local image = {
      text = {},
      textcol = {}
    }
    local fs = fs
    if OneOS then
      fs = OneOS.FS
    end
    if fs.exists(path) then
      local _open = io.open
      local file = _open(path, "r")
      local sLine = file:read()
      local num = 1
      while sLine do  
        table.insert(image, num, {})
        table.insert(image.text, num, {})
        table.insert(image.textcol, num, {})
                                              
        --As we're no longer 1-1, we keep track of what index to write to
        local writeIndex = 1
        --Tells us if we've hit a 30 or 31 (BG and FG respectively)- next char specifies the curr colour
        local bgNext, fgNext = false, false
        --The current background and foreground colours
        local currBG, currFG = nil,nil
        for i=1,#sLine do
          local nextChar = string.sub(sLine, i, i)
          if nextChar:byte() == 30 then
            bgNext = true
          elseif nextChar:byte() == 31 then
            fgNext = true
          elseif bgNext then
            currBG = Drawing.GetColour(nextChar)
            bgNext = false
          elseif fgNext then
            currFG = Drawing.GetColour(nextChar)
            fgNext = false
          else
            if nextChar ~= " " and currFG == nil then
              currFG = colours.white
            end
            image[num][writeIndex] = currBG
            image.textcol[num][writeIndex] = currFG
            image.text[num][writeIndex] = nextChar
            writeIndex = writeIndex + 1
          end
        end
        num = num+1
        sLine = file:read()
      end
      file:close()
    end
    return image
  end,

  DrawCharactersCenter = function(x, y, w, h, characters, textColour,bgColour)
    w = w or Drawing.Screen.Width
    h = h or Drawing.Screen.Height
    x = x or 0
    y = y or 0
    x = math.ceil((w - #characters) / 2) + x
    y = math.floor(h / 2) + y

    Drawing.DrawCharacters(x, y, characters, textColour, bgColour)
  end,

  GetColour = function(hex)
    if hex == ' ' then
      return colours.transparent
    end
      local value = tonumber(hex, 16)
      if not value then return nil end
      value = math.pow(2,value)
      return value
  end,

  Clear = function (_colour)
    _colour = _colour or colours.black
    Drawing.ClearBuffer()
    Drawing.DrawBlankArea(1, 1, Drawing.Screen.Width, Drawing.Screen.Height, _colour)
  end,

  Buffer = {},
  BackBuffer = {},

  DrawBuffer = function()
    for y,row in pairs(Drawing.Buffer) do
      for x,pixel in pairs(row) do
        local shouldDraw = true
        local hasBackBuffer = true
        if Drawing.BackBuffer[y] == nil or Drawing.BackBuffer[y][x] == nil or #Drawing.BackBuffer[y][x] ~= 3 then
          hasBackBuffer = false
        end
        if hasBackBuffer and Drawing.BackBuffer[y][x][1] == Drawing.Buffer[y][x][1] and Drawing.BackBuffer[y][x][2] == Drawing.Buffer[y][x][2] and Drawing.BackBuffer[y][x][3] == Drawing.Buffer[y][x][3] then
          shouldDraw = false
        end
        if shouldDraw then
          term.setBackgroundColour(pixel[3])
          term.setTextColour(pixel[2])
          term.setCursorPos(x, y)
          term.write(pixel[1])
        end
      end
    end
    Drawing.BackBuffer = Drawing.Buffer
    Drawing.Buffer = {}
    term.setCursorPos(1,1)
  end,

  ClearBuffer = function()
    Drawing.Buffer = {}
  end,

  WriteStringToBuffer = function (x, y, characters, textColour,bgColour)
    for i = 1, #characters do
        local character = characters:sub(i,i)
        Drawing.WriteToBuffer(x + i - 1, y, character, textColour, bgColour)
    end
  end,

  WriteToBuffer = function(x, y, character, textColour,bgColour)
    x = round(x)
    y = round(y)
    if bgColour == colours.transparent then
      Drawing.Buffer[y] = Drawing.Buffer[y] or {}
      Drawing.Buffer[y][x] = Drawing.Buffer[y][x] or {"", colours.white, colours.black}
      Drawing.Buffer[y][x][1] = character
      Drawing.Buffer[y][x][2] = textColour
    else
      Drawing.Buffer[y] = Drawing.Buffer[y] or {}
      Drawing.Buffer[y][x] = {character, textColour, bgColour}
    end
  end,
}

Button = {
  X = 1,
  Y = 1,
  Width = 0,
  Height = 0,
  BackgroundColour = colours.lightGrey,
  TextColour = colours.white,
  ActiveBackgroundColour = colours.lightGrey,
  Text = "",
  Parent = nil,
  _Click = nil,
  Toggle = nil,

  AbsolutePosition = function(self)
    return self.Parent:AbsolutePosition()
  end,

  Draw = function(self)
    local bg = self.BackgroundColour
    local tc = self.TextColour
    if type(bg) == 'function' then
      bg = bg()
    end

    if self.Toggle then
      tc = colours.white
      bg = self.ActiveBackgroundColour
    end

    local pos = GetAbsolutePosition(self)
    Drawing.DrawBlankArea(pos.X, pos.Y, self.Width, self.Height, bg)
    Drawing.DrawCharactersCenter(pos.X, pos.Y, self.Width, self.Height, self.Text, tc, bg)
  end,

  Initialise = function(self, x, y, width, height, backgroundColour, parent, click, text, textColour, toggle, activeBackgroundColour)
    local new = {}    -- the new instance
    setmetatable( new, {__index = self} )
    height = height or 1
    new.Width = width or #text + 2
    new.Height = height
    new.Y = y
    new.X = x
    new.Text = text or ""
    new.BackgroundColour = backgroundColour or colours.lightGrey
    new.TextColour = textColour or colours.white
    new.ActiveBackgroundColour = activeBackgroundColour or colours.lightBlue
    new.Parent = parent
    new._Click = click
    new.Toggle = toggle
    return new
  end,

  Click = function(self, side, x, y)
    if self._Click then
      if self:_Click(side, x, y, not self.Toggle) ~= false and self.Toggle ~= nil then
        self.Toggle = not self.Toggle
        Draw()
      end
      return true
    else
      return false
    end
  end
}

Label = {
  X = 1,
  Y = 1,
  Width = 0,
  Height = 0,
  BackgroundColour = colours.lightGrey,
  TextColour = colours.white,
  Text = "",
  Parent = nil,

  AbsolutePosition = function(self)
    return self.Parent:AbsolutePosition()
  end,

  Draw = function(self)
    local bg = self.BackgroundColour
    local tc = self.TextColour

    if self.Toggle then
      tc = UIColours.MenuBarActive
      bg = self.ActiveBackgroundColour
    end

    local pos = GetAbsolutePosition(self)
    Drawing.DrawCharacters(pos.X, pos.Y, self.Text, self.TextColour, self.BackgroundColour)
  end,

  Initialise = function(self, x, y, text, textColour, backgroundColour, parent)
    local new = {}    -- the new instance
    setmetatable( new, {__index = self} )
    height = height or 1
    new.Width = width or #text + 2
    new.Height = height
    new.Y = y
    new.X = x
    new.Text = text or ""
    new.BackgroundColour = backgroundColour or colours.white
    new.TextColour = textColour or colours.black
    new.Parent = parent
    return new
  end,

  Click = function(self, side, x, y)
    return false
  end
}

ProgressBar = {
  X = 1,
  Y = 1,
  Height = 0,
  Width = 0,
  BackgroundColour = colours.lightGrey,
  BarColour = colours.blue,
  TextColour = colours.white,
  ShowText = true,
  Value = 0,
  Maximum = 1,
  Indeterminate = false,
  AnimationStep = 0,
  Parent = nil,

  AbsolutePosition = function(self)
    return self.Parent:AbsolutePosition()
  end,

  Initialise = function(self, x, y, width, height, parent, value, backgroundColour, textColour, barColour)
    local new = {}    -- the new instance
    setmetatable( new, {__index = self} )
    new.Width = width or 6
    new.Height = height or 1
    new.Y = y
    new.X = x
    new.BackgroundColour = backgroundColour or colours.lightGrey
    new.TextColour = textColour or colours.black
    new.BarColour = textColour or colours.white
    new.Parent = parent
    return new
  end,

  UpdateValue  = function(self,value)
    self.Value = value
    self.Draw()
  end,

  Draw = function(self)
    Drawing.DrawBlankArea(self.X, self.Y, self.Width, self.Height, self.BackgroundColour)
-- if self.Indeterminate then
-- for i = 1, self.Width do
-- local s = x + i - 1 + self.AnimationStep
-- if s % 4 == 1 or s % 4 == 2 then
-- Drawing.DrawBlankArea(s, y, 1, self.Height, self.BarColour)
-- end
-- end
-- self.AnimationStep = self.AnimationStep + 1
-- if self.AnimationStep >= 4 then
-- self.AnimationStep = 0
-- end
-- self.Bedrock:StartTimer(function()
-- self:Draw()
-- end, 0.25)
-- else
    local values = self.Value
    local barColours = self.BarColour
    if type(values) == 'number' then
      values = {values}
    end
    if type(barColours) == 'number' then
      barColours = {barColours}
    end
    local total = 0
    local _x = self.X
    for i, v in ipairs(values) do
      local width = (v == 0 and 0 or round((v / self.Maximum) * self.Width))
      total = total + v
      if width ~= 0 then
        Drawing.DrawBlankArea(_x, self.Y, width, self.Height, barColours[((i-1)%#barColours)+1])
      end
      _x = _x + width
    end
    if self.ShowText then
      local text = round((total / self.Maximum) * 100) .. '%'
      Drawing.DrawCharactersCenter(self.X, self.Y, self.Width, self.Height, text, self.TextColour, colours.transparent)
    end
    -- end
  end,

  Click = function(self, side, x, y)
    return false
  end
}

TextBox = {
  X = 1,
  Y = 1,
  Width = 0,
  Height = 0,
  BackgroundColour = colours.lightGrey,
  TextColour = colours.black,
  Parent = nil,
  TextInput = nil,
  Placeholder = '',

  AbsolutePosition = function(self)
    return self.Parent:AbsolutePosition()
  end,

  Draw = function(self)   
    local pos = GetAbsolutePosition(self)
    Drawing.DrawBlankArea(pos.X, pos.Y, self.Width, self.Height, self.BackgroundColour)
    local text = self.TextInput.Value
    if #tostring(text) > (self.Width - 2) then
      text = text:sub(#text-(self.Width - 3))
      if Current.TextInput == self.TextInput then
        Current.CursorPos = {pos.X + 1 + self.Width-2, pos.Y}
      end
    else
      if Current.TextInput == self.TextInput then
        Current.CursorPos = {pos.X + 1 + self.TextInput.CursorPos, pos.Y}
      end
    end
    
    if #tostring(text) == 0 then
      Drawing.DrawCharacters(pos.X + 1, pos.Y, self.Placeholder, colours.lightGrey, self.BackgroundColour)
    else
      Drawing.DrawCharacters(pos.X + 1, pos.Y, text, self.TextColour, self.BackgroundColour)
    end

    term.setCursorBlink(true)
    
    Current.CursorColour = self.TextColour
  end,

  Initialise = function(self, x, y, width, height, parent, text, backgroundColour, textColour, done, numerical)
    local new = {}    -- the new instance
    setmetatable( new, {__index = self} )
    height = height or 1
    new.Width = width or #text + 2
    new.Height = height
    new.Y = y
    new.X = x
    new.TextInput = TextInput:Initialise(text or '', function(key)
      if done then
        done(key)
      end
      Draw()
    end, numerical)
    new.BackgroundColour = backgroundColour or colours.lightGrey
    new.TextColour = textColour or colours.black
    new.Parent = parent
    return new
  end,

  Click = function(self, side, x, y)
    Current.Input = self.TextInput
    self:Draw()
  end
}

TextInput = {
  Value = "",
  Change = nil,
  CursorPos = nil,
  Numerical = false,
  IsDocument = nil,

  Initialise = function(self, value, change, numerical, isDocument)
    local new = {}    -- the new instance
    setmetatable( new, {__index = self} )
    new.Value = tostring(value)
    new.Change = change
    new.CursorPos = #tostring(value)
    new.Numerical = numerical
    new.IsDocument = isDocument or false
    return new
  end,

  Insert = function(self, str)
    if self.Numerical then
      str = tostring(tonumber(str))
    end

    local selection = OrderSelection()

    if self.IsDocument and selection then
      self.Value = string.sub(self.Value, 1, selection[1]-1) .. str .. string.sub( self.Value, selection[2]+2)
      self.CursorPos = selection[1]
      Current.Selection = nil
    else
      local _, newLineAdjust = string.gsub(self.Value:sub(1, self.CursorPos), '\n','')

      self.Value = string.sub(self.Value, 1, self.CursorPos + newLineAdjust) .. str .. string.sub( self.Value, self.CursorPos + 1  + newLineAdjust)
      self.CursorPos = self.CursorPos + 1
    end
    
    self.Change(key)
  end,

  Extract = function(self, remove)
    local selection = OrderSelection()
    if self.IsDocument and selection then
      local _, newLineAdjust = string.gsub(self.Value:sub(selection[1], selection[2]), '\n','')
      local str = string.sub(self.Value, selection[1], selection[2]+1+newLineAdjust)
      if remove then
        self.Value = string.sub(self.Value, 1, selection[1]-1) .. string.sub( self.Value, selection[2]+2+newLineAdjust)
        self.CursorPos = selection[1] - 1
        Current.Selection = nil
      end
      return str
    end
  end,

  Char = function(self, char)
    if char == 'nil' then
      return
    end
    self:Insert(char)
  end,

  Key = function(self, key)
    if key == keys.enter then
      if self.IsDocument then
        self.Value = string.sub(self.Value, 1, self.CursorPos ) .. '\n' .. string.sub( self.Value, self.CursorPos + 1 )
        self.CursorPos = self.CursorPos + 1
      end
      self.Change(key)    
    elseif key == keys.left then
      -- Left
      if self.CursorPos > 0 then
        local colShift = FindColours(string.sub( self.Value, self.CursorPos, self.CursorPos))
        self.CursorPos = self.CursorPos - 1 - colShift
        self.Change(key)
      end
      
    elseif key == keys.right then
      -- Right        
      if self.CursorPos < string.len(self.Value) then
        local colShift = FindColours(string.sub( self.Value, self.CursorPos+1, self.CursorPos+1))
        self.CursorPos = self.CursorPos + 1 + colShift
        self.Change(key)
      end
    
    elseif key == keys.backspace then
      -- Backspace
      if self.IsDocument and Current.Selection then
        self:Extract(true)
        self.Change(key)
      elseif self.CursorPos > 0 then
        local colShift = FindColours(string.sub( self.Value, self.CursorPos, self.CursorPos))
        local _, newLineAdjust = string.gsub(self.Value:sub(1, self.CursorPos), '\n','')

        self.Value = string.sub( self.Value, 1, self.CursorPos - 1 - colShift + newLineAdjust) .. string.sub( self.Value, self.CursorPos + 1 - colShift + newLineAdjust)
        self.CursorPos = self.CursorPos - 1 - colShift
        self.Change(key)
      end
    elseif key == keys.home then
      -- Home
      self.CursorPos = 0
      self.Change(key)
    elseif key == keys.delete then
      if self.IsDocument and Current.Selection then
        self:Extract(true)
        self.Change(key)
      elseif self.CursorPos < string.len(self.Value) then
        self.Value = string.sub( self.Value, 1, self.CursorPos ) .. string.sub( self.Value, self.CursorPos + 2 )        
        self.Change(key)
      end
    elseif key == keys["end"] then
      -- End
      self.CursorPos = string.len(self.Value)
      self.Change(key)
    elseif key == keys.up and self.IsDocument then
      -- Up
      if Current.Document.CursorPos then
        local page = Current.Document.Pages[Current.Document.CursorPos.Page]
        self.CursorPos = page:GetCursorPosFromPoint(Current.Document.CursorPos.Collum + page.MarginX, Current.Document.CursorPos.Line - page.MarginY - 1 + Current.Document.ScrollBar.Scroll, true)
        self.Change(key)
      end
    elseif key == keys.down and self.IsDocument then
      -- Down
      if Current.Document.CursorPos then
        local page = Current.Document.Pages[Current.Document.CursorPos.Page]
        self.CursorPos = page:GetCursorPosFromPoint(Current.Document.CursorPos.Collum + page.MarginX, Current.Document.CursorPos.Line - page.MarginY + 1 + Current.Document.ScrollBar.Scroll, true)
        self.Change(key)
      end
    end
  end
}



function Draw()
  Drawing.Clear(colours.white)
  
  if Current.StatusScreen then
    Drawing.DrawCharactersCenter(1, -6, nil, nil, Current.HeaderText, colours.blue, colours.white)
    Drawing.DrawCharactersCenter(1, -5, nil, nil, 'by farodin91', colours.lightGrey, colours.white)
    Drawing.DrawCharactersCenter(1, -3, nil, nil, Current.StatusText, Current.StatusColour, colours.white)
    if pocket or not Current.Settings.host then
      
    else
      Drawing.DrawCharactersCenter(1, 0, nil, nil, "Iris: "..Current.IrisState, colours.black, colours.white)
      Drawing.DrawCharactersCenter(1, 1, nil, nil, "Stargate: "..Current.StargateState, colours.black, colours.white)
      local time = os.time()
      Drawing.DrawCharactersCenter(1, 3, nil, nil, "Last Updated: "..time, colours.black, colours.white)
    end
  end

  for i, v in ipairs(Current.PageControls) do
    v:Draw()
  end
 
  Drawing.DrawBuffer()
 
  if Current.TextInput and Current.CursorPos and not Current.Menu and not(Current.Window and Current.Document and Current.TextInput == Current.Document.TextInput) and Current.CursorPos[2] > 1 then
    term.setCursorPos(Current.CursorPos[1], Current.CursorPos[2])
    term.setCursorBlink(true)
    term.setTextColour(Current.CursorColour)
  else
    term.setCursorBlink(false)
  end
end

function GetAbsolutePosition(object)
  local obj = object
  local i = 0
  local x = 1
  local y = 1
  while true do
    x = x + obj.X - 1
    y = y + obj.Y - 1

    if not obj.Parent then
      return {X = x, Y = y}
    end

    obj = obj.Parent

    if i > 32 then
      return {X = 1, Y = 1}
    end

    i = i + 1
  end
end

function CheckClick(object, x, y)
  if object.X <= x and object.Y <= y and object.X + object.Width > x and object.Y + object.Height > y then
    return true
  end
end

function DoClick(object, side, x, y, drag)
  local obj = GetAbsolutePosition(object)
  obj.Width = object.Width
  obj.Height = object.Height
  if object and CheckClick(obj, x, y) then
    return object:Click(side, x - object.X + 1, y - object.Y + 1, drag)
  end 
end

function TryClick( event, side, x, y, drag)
  for i,v in ipairs(Current.PageControls) do
    if DoClick(v, side, x, y, drag) then
      Draw()
      return
    end
  end
  Draw()
end