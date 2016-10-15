--[[
@title Energy Storage Monitor & Regulator
@author: zgubilembulke (november 2014)
@author: McBrown (september 2016)
@description: This script generates 3 horizontal graphs, that shows the
    power input, -output & -stored.
]]


--[[
Require's
]]
local comp = require('component');
local sides = require('sides');


--[[
Constants
]]
local STORAGE_CAPACITOR_BANK   = 0x0001
local STORAGE_INDUCTION_MATRIX = 0x0002
local POWER_EU = 0x0001
local POWER_RF = 0x0002

--[[
Config
@note:
    Limits are in percentages (e.g. 1.0 = 100%, 0.0 = 0%) where the lua's float
    precision limit is allowed 
]]
local drainLimit  = .50
local chargeLimit = .95

local storageDevice      = STORAGE_INDUCTION_MATRIX
local capacitorBankCount = 25
local powerUnits         = POWER_RF

local resX, resY       = 160, 40
local refreshRate      = 3 --screen update frequency(seconds)

local precisionDisplay = 100

local rsIoBlock = comp.redstone
local rsIoSide  = sides.back

local powerBuffer = comp.get('f5d9f17b') -- Induction Matrix
local inputSources = {
  {
    label   = 'Bio Fuel',
    address = comp.get('3f6ed800')
  }, 
  {
    label   = 'Solar Panels',
    address = comp.get('3ba48828')
  },
  {
    label   = 'Fusion Reactor',
    address = comp.get('3b6576e4')
  }
}

--[[ Don't change below this line (unless you know what you're doing) ]]

local gpu = comp.gpu

--[[
@description: Rounds a number with a certain precision
@note:
    e.g. number is 24.5635024
    precision 1000 will turn to 24.563
    precision 100 will turn to 24.56
    precision 10 will turn to 24.5
]]
function round(number, precision)
    return math.floor(number * precision) / precision
end


--[[
@description: Determines the largest number within an array
]]
function maxArrayValue(inputArray)    
    if inputArray == nil then
        return 0
    end
    
    local max = inputArray[1]

    for _, value in pairs(inputArray) do
        if value > max then
            max = value
        end
    end
   
    return max
end


--[[
@description: Determines the smallest number within an array
]]
function minArrayValue(inputArray)    
    if inputArray == nil then
        return 0
    end
        
    local min = inputArray[1]

    for _, value in pairs(inputArray) do
        if value < min then
            min = value
        end
    end
    
    return min
end


--[[
@description: Determines the size of an array 
]]
function tableLen(inputArray)
    local count = 0
    
    if inputArray ~= nil then
        for value in pairs(inputArray) do
            count = count + 1
        end
    end
    
    return count
end


--[[
@description: Shortens, rounds and makes a number humanly readable
]]
function shortenNumber(inputNumber)
    local correctionTable = {
       {letter = '',  correction = 1},
       {letter = 'k', correction = 1000},
       {letter = 'M', correction = 1000000},
       {letter = 'G', correction = 1000000000},
       {letter = 'T', correction = 1000000000000},
       {letter = 'P', correction = 1000000000000000}}
    
    for _, checkSet in ipairs(correctionTable) do
        if inputNumber <= checkSet.correction * 1000 then
            return tostring(round(inputNumber / checkSet.correction, precisionDisplay)) .. checkSet.letter
        end
    end

    return tostring(inputNumber)
end

--[[
@description: Draws a horizontal graph that grows dynamically to the size of the canvas
]]
function graphHorizontal(xPos, yPos, graphWidth, graphHeight, inputArray, addBars, detailed, pointsColor, linesColor, textColor, bgColor)
    local maxValue = maxArrayValue(inputArray)
    local minValue = 0
    local arrayLen = tableLen(inputArray)
    local legendWidth = 8 
    
    -- Determine the level of detail
    if detailed == true then
        minValue = minArrayValue(inputArray)
    end

    -- Draw canvas
    gpu.setBackground(bgColor)
    gpu.fill(xPos, yPos, graphWidth, graphHeight, ' ')
    
    -- Draw border lines
    gpu.setBackground(linesColor)
    gpu.fill(xPos + legendWidth, yPos, 1, graphHeight, ' ')
    gpu.fill(xPos, yPos + graphHeight - 1, graphWidth, 1, ' ')
    
    -- Draw & determine legend
    gpu.setBackground(bgColor)
    gpu.setForeground(textColor)
    
    -- top value legend
    gpu.set(xPos, yPos + 1, shortenNumber(maxValue))
    
    -- mid value legend
    gpu.set(xPos, yPos + 1 + (graphHeight - 2) / 2, shortenNumber(minValue + ((maxValue - minValue) / 2)))

     -- bottom value legend
    gpu.set(xPos, yPos - 1 + graphHeight - 1, shortenNumber(minValue))
    
    -- Start drawing
    local tempYPos = 0
    local tempFillerHeight = 1
    
    -- The color used to paint the background of the space-char
    gpu.setBackground(pointsColor)
    
    -- Shift the array
    if arrayLen > graphWidth - (legendWidth + 1) then
        table.remove(inputArray, 1)
    end

    -- Draw points/bars
    for key, value in pairs(inputArray) do
        tempYPos = math.floor(yPos + 1 + (graphHeight - 3) - (((value - minValue) / (maxValue - minValue)) * (graphHeight - 3)))
    
        if addBars == true then
            tempFillerHeight = yPos + graphHeight - tempYPos - 1
        end
    
        gpu.fill(xPos + legendWidth + key, tempYPos, 1, tempFillerHeight, ' ')
    end
end


--[[
@description: Draws a label on a specified location, text is always centered
]]
function drawLabel(xPos, yPos, labelWidth, bgColor, textColor, textLabel)
    gpu.setBackground(bgColor)
    gpu.setForeground(textColor)
    gpu.fill(xPos, yPos, labelWidth, 1, ' ')
    gpu.set(xPos + ((labelWidth / 2) - (string.len(textLabel) / 2)), yPos, tostring(textLabel))
end


--[[
@description: sets charging-state and toggles the Redstone IO block 
]]
function setCharging(charging)
  isCharging = charging
 
  if charging == true then
    rsIoBlock.setOutput(rsIoSide, 250)
  else
    rsIoBlock.setOutput(rsIoSide, 0)
  end
end


--[[
Script start
]]
isCharging     = false

local storageObj     = nil
local capacity       = 0
local previousEnergy = 0
local powerCalc      = 1
local capacity       = 0
local storedLabel    = ''

inputArrays  = {}
outputArray = {}
storedArray = {}

-- Determine power-units for powerUnit & -mod calculations
if storageDevice == STORAGE_CAPACITOR_BANK
    and powerUnits == POWER_RF then
        powerCalc = powerCalc
elseif storageDevice == STORAGE_CAPACITOR_BANK
    and powerUnits == POWER_EU then
        powerCalc = powerCalc * .4
elseif storageDevice == STORAGE_INDUCTION_MATRIX
    and powerUnits == POWER_RF then
        powerCalc = powerCalc * .4
elseif storageDevice == STORAGE_INDUCTION_MATRIX
    and powerUnits == POWER_EU then
        -- Do absolutely nothing
end

setCharging(false)

-- Set resolution
gpu.setResolution(resX, resY)

-- Determine storage device
if storageDevice == STORAGE_CAPACITOR_BANK then
    storageObj = comp.tile_blockcapacitorbank_name
    capacity   = storageObj.getMaxEnergyStored() * capacitorBankCount * powerCalc
elseif storageDevice == STORAGE_INDUCTION_MATRIX then
    comp.setPrimary('induction_matrix', powerBuffer)
    storageObj = comp.getPrimary('induction_matrix')
    capacity   = storageObj.getMaxEnergy() * powerCalc
end

-- Draw top label
drawLabel(1, 1, 160, 0x222222, 0xFFFFFF, 'ENERGY MONITOR')

-- Draw legend
drawLabel(1, resY, 160, 0x222222, 0x969696, '(Drain limit: ' .. round(drainLimit * 100, 100) .. '%, Charge limit: ' .. round(chargeLimit * 100, 100) .. '%)')

--[[
Begin application loop
]]
repeat
    -- Determine storage device
    if storageDevice == STORAGE_CAPACITOR_BANK then
        stored = storageObj.getEnergyStored() * capacitorBankCount * powerCalc 
        if previousEnergy > stored then
              input  = 0
              output = previousEnergy - stored
        elseif previousEnergy < stored then
              input  = stored - previousEnergy
              output = 0
        else
              input  = 0
              output = 0
        end
        previousEnergy = stored
    elseif storageDevice == STORAGE_INDUCTION_MATRIX then
        for key, inputID in pairs(inputSources) do
            comp.setPrimary('induction_matrix', inputID.address)
            input[key]  = comp.getPrimary('induction_matrix').getInput() * powerCalc
        end
        output = storageObj.getOutput() * powerCalc
        stored = storageObj.getEnergy() * powerCalc
    end

    storedPrc = stored / capacity

    for key, inputVal in pairs(input)
        table.insert(inputArrays[key], inputVal)
    end

    table.insert(outputArray, output)
    table.insert(storedArray, stored)

    gpu.setBackground(0x141414) -- main background color
    gpu.fill(1, 2, resX, resY - 2, ' ')

    totalWidth  = 160
    columnWidth = totalWith / #inputArrays
    columnGap   = 2
    for key, inputArray in pairs(inputArrays)
        graphHorizontal(math.ceil(columnGap / 2), 4, columnWidth - columnGap, 17, inputArray, true, false, 0x66CC00, 0xFFFFFF, 0xFFFFFF, 0x333333)
    end

    graphHorizontal(134, 23, 26, 16, outputArray, true, false, 0xFF3232, 0xFFFFFF, 0xFFFFFF, 0x333333)
    graphHorizontal(2, 23, 130, 16, storedArray, false, true, 0x2E87D8, 0xFFFFFF, 0xFFFFFF, 0x333333)

    drawLabel(2, 3, 78, 0x222222, 0xFFFFFF, 'INPUT: ' .. shortenNumber(input) .. 'RF')
    drawLabel(82, 3, 78, 0x222222, 0xFFFFFF, 'OUTPUT: ' .. shortenNumber(output) .. 'RF')

    storedLabel = shortenNumber(stored) .. 'RF (' .. round(storedPrc * 100, 100) .. '%)';
    
    if isCharging == true then
        drawLabel(2, 22, 130, 0x222222, 0x66CC00, storedLabel .. ' - CHARGING')
    else
        drawLabel(2, 22, 130, 0x222222, 0xFFFFFF, storedLabel)
    end

    drawLabel(134, 22, 26, 0x222222, 0xFFFFFF, 'Output')

    -- Check and toggle charging state
    if isCharging == false and storedPrc <= drainLimit then
        setCharging(true)
    elseif isCharging == true and storedPrc >= chargeLimit then
        setCharging(false)
    end
    
    -- Don't loop like a truck beserker
    gpu.setForeground(0xFFFFFF)
    os.sleep(refreshRate)
    
until false