-- Original clock by Fingercomp. Edit by Tweakcraft.

MT_BG    = 0x000000 -- ingame time background
MT_FG    = 0xFFFFFF -- ingame time foreground
DAY      = 0xFFFF00
EVENING  = 0x202080
NIGHT    = 0x000080
MORNING  = 0x404000
RT_BG    = 0xCC0000 -- real time background
RT_FG    = 0xFFFFFF -- real time foreground
TIMEZONE = 2
CORRECT  = 0
W, H     = 32, 8
REDSTONE = false
TOUCH    = true
KEY1     = 13
KEY2     = 28
SHOWSECS = true
AUTOMODE = false
SWDATEMT = true
SWDATERT = true
SWDTMMT  = false
SWDTMRT  = false
 
local com     = require("component")
local gpu     = com.gpu
local unicode = require("unicode")
local fs      = require("filesystem")
local event   = require("event")
local term    = require("term")
 
oldw, oldh = gpu.getResolution()
gpu.setResolution(W, H)
w, h = gpu.getResolution()
mode = AUTOMODE
noExit = true
 
tz = TIMEZONE + CORRECT
local nums = {}
nums[0] = {"███", "█ █", "█ █", "█ █", "███"}
nums[1] = {"██ ", " █ ", " █ ", " █ ", "███"}
nums[2] = {"███", "  █", "███", "█  ", "███"}
nums[3] = {"███", "  █", "███", "  █", "███"}
nums[4] = {"█ █", "█ █", "███", "  █", "  █"}
nums[5] = {"███", "█  ", "███", "  █", "███"}
nums[6] = {"███", "█  ", "███", "█ █", "███"}
nums[7] = {"███", "  █", "  █", "  █", "  █"}
nums[8] = {"███", "█ █", "███", "█ █", "███"}
nums[9] = {"███", "█ █", "███", "  █", "███"}
 
dts = {}
dts[1] = "Night"
dts[2] = "Morning"
dts[3] = "Day"
dts[4] = "Evening"
 
local function centerX(str)
  local len
  if type(str) == "string" then
    len = unicode.len(str)
  elseif type(str) == "number" then
    len = str
  else
    error("Number excepted")
  end
  local whereW, _ = math.modf(w / 2)
  local whereT, _ = math.modf(len / 2)
  local where = whereW - whereT + 1
  return where
end
 
local function centerY(lines)
  local whereH, _ = math.modf(h / 2)
  local whereT, _ = math.modf(lines / 2)
  local where = whereH - whereT -- + 1
  return where
end
 
local t_correction = tz * 3600
 
local function getTime()
    local file = io.open('/tmp/clock.dt', 'w')
    file:write('')
    file:close()
    local lastmod = tonumber(string.sub(fs.lastModified('/tmp/clock.dt'), 1, -4)) + t_correction
 
    local year = os.date('%Y', lastmod)
    local month = os.date('%m', lastmod)
    local day = os.date('%d', lastmod)
    local weekday = os.date('%A', lastmod)
    local hour = os.date('%H', lastmod)
    local minute  = os.date('%M', lastmod)
    local sec  = os.date('%S', lastmod)    
    return year, month, day, weekday, hour, minute, sec
end
 
local function sn(num)
  -- SplitNumber
  local n1, n2
  if num >= 10 then
    n1, n2 = tostring(num):match("(%d)(%d)")
    n1, n2 = tonumber(n1), tonumber(n2)
  else
    n1, n2 = 0, num
  end
  return n1, n2
end
 
local function drawNumbers(hh, mm, ss)
  local firstLine = centerY(5)
  local n1, n2, n3, n4, n5, n6
  n1, n2 = sn(hh)
  n3, n4 = sn(mm)
  if ss ~= nil then
    n5, n6 = sn(ss)
  end
--print(n1, n2, n3, n4, n5, n6, type(n1))
  for i = 1, 5, 1 do
    local sep
    if i == 2 or i == 4 then
      sep = " █ "
    else
      sep = "   "
    end
    local lineToDraw = ""
    if ss ~= nil then
      lineToDraw = nums[n1][i] .. "  " .. nums[n2][i] .. sep .. nums[n3][i] .. "  " .. nums[n4][i] .. sep .. nums[n5][i] .. "  " .. nums[n6][i]
    else
      lineToDraw = nums[n1][i] .. "  " .. nums[n2][i] .. sep .. nums[n3][i] .. "  " .. nums[n4][i]
    end
    gpu.set(centerX(lineToDraw), firstLine + i - 1, lineToDraw)
  end
end
 
local function setDaytimeColor(hh, mm)
  local daytime
  if (hh == 19 and mm >= 30) or (hh > 19 and hh < 22) then
    daytime = 4
    gpu.setForeground(EVENING)
  elseif hh >= 22 or hh < 6 then
    daytime = 1
    gpu.setForeground(NIGHT)
  elseif hh >= 6 and hh < 12 then
    daytime = 2
    gpu.setForeground(MORNING)
  elseif (hh >= 12 and hh < 19) or (hh == 19 and mm < 30) then
    daytime = 3
    gpu.setForeground(DAY)
  end
  return daytime
end
 
local function drawMT()
  local year, month, day, hh, mm = os.date():match("(%d+)/(%d+)/(%d+)%s(%d+):(%d+):%d+")
  hh, mm = tonumber(hh), tonumber(mm)
  gpu.fill(1, 1, w, h, " ")
  drawNumbers(hh, mm)
  if SWDTMMT then
    local dtm = setDaytimeColor(hh, mm)
    gpu.set(centerX(dts[dtm]), centerY(5) - 1, dts[dtm])
  end
  gpu.setForeground(MT_FG)
  if SWDATEMT then
    gpu.set(centerX(year .. "/" .. month .. "/" .. day), centerY(1) + 3, year .. "/" .. month .. "/" .. day)
  end
end
 
local function drawRT()
  local year, month, day, wd, hh, mm, ss = getTime()
  gpu.fill(1, 1, w, h, " ")
  hh, mm, ss = tonumber(hh), tonumber(mm), tonumber(ss)
  if not SHOWSECS then
    ss = nil
  end
  drawNumbers(hh, mm, ss)
  if SWDTMRT then
    local dtm = setDaytimeColor(hh, mm)
    gpu.set(centerX(dts[dtm]), centerY(5) - 1, dts[dtm])
  end
  gpu.setForeground(RT_FG)
  local infoLine = wd .. ", " .. day .. "-" .. month .. "-" .. year
  if SWDATERT then
    gpu.set(centerX(infoLine), centerY(1) + 3, infoLine)
  end
end
 
local function cbFunc()
  if mode == true then mode = false gpu.setBackground(RT_BG) gpu.setForeground(RT_FG) else mode = true gpu.setBackground(MT_BG) gpu.setForeground(MT_FG) end
end
 
local function checkKey(name, addr, key1, key2)
  if key1 == KEY1 and key2 == KEY2 then
    noExit = false
  end
end
 
gpu.fill(1, 1, w, h, " ")
if TOUCH then
  event.listen("touch", cbFunc)
end
if REDSTONE then
  event.listen("redstone_changed", cbFunc)
end
event.listen("key_down", checkKey)
term.setCursor(1, 1)
while noExit do
  if mode == true then
    drawMT()
  else
    drawRT()
  end
  os.sleep(1)
end
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
gpu.setResolution(oldw, oldh)
gpu.fill(1, 1, oldw, oldh, " ")
