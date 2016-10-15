--[[
@title Energy Storage Monitor & Regulator
@author: zgubilembulke (november 2014)
@author: McBrown (september 2016)
@description: This script generates 3 horizontal graphs, that shows the
    power input, -output & -stored.
    MULTI-INPUT EDITION
]]

--[[
Require's
]]
local comp  = require('component');
local sides = require('sides');

--[[
Constants
]]
local POWER_EU = 0x0001
local POWER_RF = 0x0002

--[[
Config
@note:
    Limits are in percentages (e.g. 1.0 = 100%, 0.0 = 0%) where the lua's float
    precision limit is allowed 
]]
local regulateLimits = true
local drainLimit     = .50
local chargeLimit    = .95

local powerUnits       = POWER_RF

local resX, resY       = 160, 40
local refreshRate      = 3 --screen update frequency(seconds)

local precisionDisplay = 100

local rsIoBlock = comp.redstone
local rsIoSide  = sides.back

local powerBuffer =  -- Induction Matrix
local inductionMatrixTable = {
    storage = {
        label   = 'Power Storage'
        lookup  = 'f5d9f17b'
    },
    inputs = {
        {
            label  = 'Bio Fuel',
            lookup = '3f6ed800'
        }, 
        {
            label  = 'Solar Panels',
            lookup = '3ba48828'
        },
        {
            label  = 'Fusion Reactor',
            lookup = '3b6576e4'
        }
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
@description: Sets charging-state and toggles the Redstone IO block 
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
@description: Augments the table with the actual objects, so they dont have to
    be collected at a later time.
]]

function augmentTable(inductionMatrix)
    inductionMatrix.realAddress = comp.get(inductionMatrix.address)
    inductionMatrix.proxy       = comp.proxy(inductionMatrix.realAddress)
end

--[[
Script start
]]
local powerCalc   = 1

-- Array's that are pushed and popped
local inputArrays = {}
local outputArray = {}
local storedArray = {}

-- Set resolution
gpu.setResolution(resX, resY)    
gpu.setBackground(0x141414) -- main background color

-- Determine if limits need to be regulated
if regulateLimits == true then
    isCharging = false
    setCharging(false)
end

-- Determine power-units for powerUnit & -mod calculations
if powerUnits == POWER_RF then
    powerUnitText = 'RF'
    powerCalc     = powerCalc * .4
elseif powerUnits == POWER_EU then
    powerUnitText = 'EU'
end

augmentTable(inductionMatrixTable.storage)
for _, inputRef in pairs(inductionMatrixTable.inputs) do
    augmentTable(inputRef)
end

-- Draw top label & legend
drawLabel(1, 1, 160, 0x222222, 0xFFFFFF, 'ENERGY MONITOR')
drawLabel(1, resY, 160, 0x222222, 0x969696, '(Drain limit: ' .. round(drainLimit * 100, 100) .. '%, Charge limit: ' .. round(chargeLimit * 100, 100) .. '%)')

--[[
Begin application loop
]]
repeat
    gpu.setBackground(0x000000)
    gpu.fill(1, 2, resX, resY - 2, ' ')
    
    -- Prepare datasets
    for key, inputItem in pairs(inductionMatrixTable.inputs) do
        table.insert(inputArrays[key], inputItem.getInput() * powerCalc)
    end
    table.insert(outputArray, inductionMatrixTable.storage.getOutput() * powerCalc)
    table.insert(storedArray, inductionMatrixTable.storage.getEnergy() * powerCalc)
    
    
    storedPrc = inductionMatrixTable.storage / capacity
    
    -- Check and toggle charging state
    if regulateLimits == true then
        if isCharging == false and storedPrc <= drainLimit then
            setCharging(true)
        elseif isCharging == true and storedPrc >= chargeLimit then
            setCharging(false)
        end
    end
    
    columnWidth = resX / #inputArrays
    columnGap   = 2
    for key, inputArray in pairs(inputArrays) do
        graphHorizontal(math.ceil(columnGap / 2), 4, columnWidth - columnGap, 17, inputArray, true, false, 0x66CC00, 0xFFFFFF, 0xFFFFFF, 0x333333)
    end

    graphHorizontal(2, 23, 130, 16, storedArray, false, true, 0x2E87D8, 0xFFFFFF, 0xFFFFFF, 0x333333)
    graphHorizontal(134, 23, 26, 16, outputArray, true, false, 0xFF3232, 0xFFFFFF, 0xFFFFFF, 0x333333)
    
    -- drawLabel(2, 3, 78, 0x222222, 0xFFFFFF, 'INPUT: ' .. shortenNumber(input) .. 'RF')
    drawLabel(134, 22, 26, 0x222222, 0xFFFFFF, 'OUTPUT: ' .. shortenNumber(input))
    
    storedLabel = shortenNumber(stored) .. 'RF (' .. round(storedPrc * 100, 100) .. '%)';
    
    if regulateLimits == true and isCharging == true then
        drawLabel(2, 22, 130, 0x222222, 0x66CC00, storedLabel .. ' - CHARGING')
    else
        drawLabel(2, 22, 130, 0x222222, 0xFFFFFF, storedLabel)
    end
    
    -- Don't loop like a truck beserker
    gpu.setForeground(0xFFFFFF)
    os.sleep(refreshRate)
    
until false