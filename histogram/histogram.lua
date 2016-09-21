-- coded by zgubilembulke
-- modified by McBrown (september 2016)
 
local comp = require('component');
local sides = require('sides');
 
local drainLimit  = .14
local chargeLimit = .14025
 
local rsIoBlock = comp.redstone -- default
local rsIoSide  = sides.left -- (top, bottom, front, back, left, right)
 
-- Don't change below this line (unless you know what you're doing) --
 
local gpu = comp.gpu
local matrix = comp.induction_matrix
local isCharging = false
local refresh_rate = 1 --screen update frequency(seconds)
 
gpu.setResolution(160,40) -- set resolution
w,h = gpu.getResolution()
 
function round(t)
  return math.floor(t*100)*0.01
end
 
function max_array_value(array)
  local max = 0
  for k, v in pairs(array) do
      if v > max then
          max = v
      end
  end
  return max
end
 
function min_array_value(array)
  local min = array[1]
  for k, v in pairs(array) do
      if v < min then
          min = v
      end
  end
  return min
end
 
function tablelen(array)
  local count = 0
  for _ in pairs(array) do count = count + 1 end
  return count
end
 
function shorter_number(num)
  if num <= 1000 then
    return tostring(num)
  elseif num <= 1000000 then
    return tostring(round(num/1000)) .. "k"
  elseif num <= 1000000000 then
    return tostring(round(num/1000000)) .. "M"
  elseif num <= 1000000000000 then
    return tostring(round(num/1000000000)) .. "G"
  elseif num <= 1000000000000000 then
    return tostring(round(num/1000000000000)) .. "T"
  else
    return '';
  end
end
 
function graph_horizontal(xpos,ypos,g_width,g_height,array,addbars_bool,detailed_bool,points_color,lines_color,text_color,bg_color)
  local maxvalue = max_array_value(array)
  local minvalue = 0
  if detailed_bool == true then
    minvalue = min_array_value(array)
  end
 
  local arraylen = tablelen(array)
  gpu.setBackground(bg_color)
  gpu.fill(xpos,ypos,g_width,g_height,' ')
  gpu.setBackground(lines_color)
  gpu.fill(xpos+7,ypos,1,g_height," ") -- change by McB
  gpu.fill(xpos,ypos+g_height-1,g_width,1," ")  
  gpu.setBackground(bg_color)
  gpu.setForeground(text_color)
 -- gpu.set(xpos+((g_width/2)-(string.len(labelText)/2)), ypos-1, tostring(labelText))                    -- place label
  gpu.set(xpos,ypos+1,tostring(shorter_number(maxvalue)))                                               -- top value display
  gpu.set(xpos,ypos+1+(g_height-2)/2,tostring(shorter_number(minvalue+((maxvalue-minvalue)/2))) )              -- mid value display
  gpu.set(xpos,ypos-1+g_height-1,tostring(shorter_number(minvalue)) )                                                                  -- 0 value display
  gpu.setBackground(points_color)                                                                             --graph color
    if arraylen > g_width-8 then -- change by McB
      table.remove(array,1)
    end
 
  if addbars_bool == true then
    for a,b in pairs(array)do
      local yp=math.floor(ypos+1+(g_height-3)-(((b-minvalue)/(maxvalue-minvalue))*(g_height-3)))
      gpu.fill(xpos+7+a,yp,1,ypos+g_height-yp-1," ")    -- vertical bars version -- changed by McB
    end
  elseif addbars_bool ~= true then
    for a,b in pairs(array)do
      local yp=math.floor(ypos+1+(g_height-3)-(((b-minvalue)/(maxvalue-minvalue))*(g_height-3)))
      gpu.fill(xpos+7+a,yp,1,1," ")  -- single point version -- changed by McB
    end
  end
end
 
function drawLabel(xPos, yPos, width, bgColor, textColor, textLabel)
  gpu.setBackground(bgColor)
  gpu.setForeground(textColor)
  gpu.fill(xPos, yPos, width, 1, " ")
  gpu.set(xPos+((width/2)-(string.len(textLabel)/2)), yPos, tostring(textLabel))
end
 
function setCharging(charging)
  isCharging = charging
 
  if charging == true then
    rsIoBlock.setOutput(rsIoSide, 250)
  else
    rsIoBlock.setOutput(rsIoSide, 0)
  end
end
 
setCharging(false)
 
array1 = {}
array2 = {}
array3 = {}
 
--local previousEnergy = 0
local capacity = matrix.getMaxEnergy() * .4
 
repeat -- Begin loop
 
input     = matrix.getInput() * .4
output    = matrix.getOutput() * .4
stored    = matrix.getEnergy() * .4
storedPrc = stored / capacity
 
--stored = comp.tile_blockcapacitorbank_name.getEnergyStored() * capacitorBankCount
--if previousEnergy > stored then
--  input   = 0
--  output  = previousEnergy - stored
--elseif previousEnergy < stored then
--  input   = stored - previousEnergy
--  output  = 0
--else
--  input   = 0
--  output  = 0
--end
 
table.insert(array1, input)
table.insert(array2, output)
table.insert(array3, stored)
 
gpu.setBackground(0x141414) -- main background color
gpu.fill(1,1,w,h,' ')
 
graph_horizontal(2,5,78,17,array1,true,true,0x66CC00,0xFFFFFF,0xFFFFFF,0x333333)
graph_horizontal(82,5,78,17,array2,true,false,0xFF3232,0xFFFFFF,0xFFFFFF,0x333333)
graph_horizontal(2,24,158,13,array3,true,true,0x2E87D8,0xFFFFFF,0xFFFFFF,0x333333)
 
drawLabel(2, 4, 78, 0x222222, 0xFFFFFF, 'INPUT: ' .. shorter_number(input) .. 'RF')
drawLabel(82, 4, 78, 0x222222, 0xFFFFFF, 'OUTPUT: ' .. shorter_number(output) .. 'RF')
 
storedLabel = 'STORED: ' .. shorter_number(stored) .. 'RF (' .. round(storedPrc*100) .. '%)'
 
if isCharging then
  drawLabel(2, 23, 158, 0x222222, 0x66CC00, storedLabel .. ' - CHARGING')
else
  drawLabel(2, 23, 158, 0x222222, 0xFFFFFF, storedLabel)
end
 
--previousEnergy = stored
 
-- Check and toggle charging
 
drawLabel(1, 1, 158, 0x222222, 0xFFFFFF, 'Olle grieze!!!');
 
-- Debug label
-- drawLabel(1, 1, 158, 0x000000, 0xFFFFFF, 'Debug: isCharging:' .. tostring(isCharging) .. ', storedPrc:' .. tostring(storedPrc) .. ', drainLimit:' .. drainLimit)
 
if isCharging == false and storedPrc <= drainLimit then
  setCharging(true)
elseif isCharging == true and storedPrc >= chargeLimit then
  setCharging(false)
end
 
os.sleep(refresh_rate)
until false
