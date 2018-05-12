-- ********************************************************************************** --
-- **                                                                              ** --
-- **   Minecraft AE2 Auto-Stocker by RandomBlue (E.J. Wilburn)                    ** --
-- **   Converted to OpenComputers by Felthry                                      ** --
-- **   ----------------------------------------------------                       ** --
-- **                                                                              ** --
-- **   This program automatically crafts items necessary to maintain a minimum    ** --
-- **   stock level of specific items.  The items are configured in a file on      ** --
-- **   an openComputers computer named stock_list.txt in the autostock directory. ** --
-- **   Examine that file for example formatting and details.                      ** --
-- **                                                                              ** --
-- **   Minimum stock levels and crafting batch sizes are configurable per item.   ** --
-- **                                                                              ** --
-- **   The computer must be connected to an adapter adjacent to a full block ME   ** --
-- **   Interface linked to an ME Network where both the items are stored and the  ** --
-- **   crafting CPUs are located.  Each item you wish to maintain a stock level   ** --
-- **   for must have autocrafting enabled for it.                                 ** --
-- **                                                                              ** --
-- **   Arguments                                                                  ** --
-- **   ----------------------------------------------------                       ** --
-- **   checkFrequency (optional) - How often inventory levels are checked in      ** --
-- **                               seconds.                                       ** --
-- **   stockFileName (optional)  - Full path to the file containing stocking      ** --
-- **                               requirements.                                  ** --
-- **                                                                              ** --
-- **  Change Log:                                                                 ** --
-- **    8th Sep 2015:  [v0.1]  Initial Release                                    ** --
-- **    11th Sep 2015: [v0.11] Minor bug fix - attempting to crafting 0 items     ** --
-- **                           when current quantity equals minQuantity           ** --
-- **    22nd Aug 2016: [vF.1]  Converted to OpenComputers. Automatic generation   ** --
-- **                           of autorun file no longer supported                ** --
-- **    23rd Aug 2016: [vF.11] A few redundant functions removed, and some minor  ** --
-- **                           bug fixes; no longer wants an attachSide parameter ** --
-- **                           and now displays time properly.                    ** --
-- **    27th Aug 2016: [vF.12] Added more display functionality. The program now  ** --
-- **                           shows current stock levels, crafting status (sort  ** --
-- **                           of) and if something can't be crafted because the  ** --
-- **                           ME network lacks a free crafting CPU               ** --
-- **                                                                              ** --
-- **  TODO:                                                                       ** --
-- **    1) Convert startup script to be compatible with OpenComputers             ** --
-- **    2) Save command line parameters to startup script.                        ** --
-- **                                                                              ** --
-- ********************************************************************************** --
 
 
-- libraries
local fs = require("filesystem")
local component = require("component")
local serialization = require("serialization")
local event = require("event")
local tab = require("keyboard").keys.tab
 
-- Parameters with default values.
local checkFrequency = 300 -- How often inventory levels are checked in seconds.  Overridden by passing as the first argument.
local stockFileName = "/autostock/stock_list.txt" -- Change this if you want the file somewhere else.  Can be
                                                  -- overridden via a parameter.
local recraftDelay = 600 -- Delay, in seconds, before allowing an item to be crafted again.  If them item in question exceeds
                         -- its min quantity before the delay expires, the delay is reset as it's assumed the job
                         -- completed.  300 seconds = 5 minutes
local delayedItems = {} -- List of delayed items by id:variant with delay time in seconds.  Decremented each loop by
                        -- checkFrequency ammount.  When the delay hits 0 or lower then the item is removed from
                        -- the list.
 
local DEBUG = false
local running = true
local stocks = nil
 
-- Process the input arguments - storing them to global variables
local args = { ... }
 
local events = setmetatable({}, {__index = function() return function() end end})
function events.key_up(keyboard, char, code, player)
  if (code == tab) then
    running = false
  end
end
 
function handleEvent(event, ...)
  if (event) then
    events[event](...)
  end
end
 
function checkInventory(ae2)
  print("[" .. getDisplayTime() .. "] Checking inventory. Press TAB to exit.")
  updateDelayedItems(delayedItems)
  local allItems = getAllItems(ae2)
  for i=1, #allItems do
    if (allItems[i].is_craftable == true) then
      stockItem(allItems[i], stocks, ae2)
    end
  end
end
 
local timerEvent = event.timer(checkFrequency, function() checkInventory(ae2) end, math.huge)
 
function main(args)
  processArgs(args)
  stocks = loadStockFile(stockFileName)
  displayStockingInfo(stocks)
--  enableAutoRestart()
 
  checkInventory(ae2)
  while (running) do
    handleEvent(event.pull())
  end
end
  
function processArgs(args)
  if (#args >= 1) then
    assert(type(args[1]) == "number", "The first parameter (checkFrequency) must be a number.")
    checkFrequency = args[1]
  end
 
  if (#args > 1) then
    assert(type(args[2]) == "string", "The second parameter (stockFileName) must be a string.")
    stockFileName = args[2]
  end
  assert(fs.exists(stockFileName), "The stock file does not exist: " .. stockFileName)
end
 
function attachToAe2()
  -- Make sure there is actually an ME Interface attached.
  assert(component.isAvailable("me_interface"), "Error: The computer must be connected to an adapter adjacent to an ME interface.")
  return component.getPrimary("me_interface")
end
 
function loadStockFile(stockFileName)
  local stockFile = io.open(stockFileName, "r")
  local stockFileContents = stockFile:read("*a");
  stockFile:close();
  local outputStocks = serialization.unserialize(stockFileContents)
 
  if (DEBUG) then
    print("Stock file: ")
    print(stockFileContents)
    print("Output stocks length: " .. #outputStocks)
    print("Output stocks: ")
    for i=1, #outputStocks do
      print("itemId: " .. outputStocks[i].itemId)
      print("variant: " .. outputStocks[i].variant)
      print("minQuantity: " .. outputStocks[i].minQuantity)
      print("batchSize: " .. outputStocks[i].batchSize)
    end
  end
 
  assert(#outputStocks > 0, "There are no entries in the " .. stockFileName .. " file.")
  return outputStocks
end
 
function displayStockingInfo(stocks)
  print("Stocking info:")
  for i=1, #stocks do
    print(" item: " .. stocks[i].displayName .. " minQuantity: " .. stocks[i].minQuantity ..
      " batchSize: " .. stocks[i].batchSize)
  end
end
 
function getAllItems(ae2)
  local outputAllItems = ae2.getAvailableItems()
  assert(outputAllItems ~= nil, "No craftable items found in this AE2 network.")
  assert(#outputAllItems > 0, "No craftable items found in this AE2 network.")
  return outputAllItems
end
 
function isCpuAvailable(ae2)
  local cpus = ae2.getCraftingCPUs()
  for i=1, #cpus do
    if (cpus[i].busy == false) then return true end
  end
  return false
end
 
function findStockSetting(fingerprint, stocks)
  for i=1, #stocks do
    if (stocks[i].itemId == fingerprint.id and stocks[i].variant == fingerprint.dmg) then
      return stocks[i]
    end
  end
  return nil
end
 
function stockItem(currItem, stocks, ae2)
  local stockSetting = findStockSetting(currItem.fingerprint, stocks)
 
  if (stockSetting == nil) then return end
  if (currItem.size >= stockSetting.minQuantity) then
    print(stockSetting.displayName .. ": " .. currItem.size .. "≥" .. stockSetting.minQuantity)
    return
  end
  if (isDelayed(currItem.fingerprint, delayedItems)) then
    print(stockSetting.displayName .. ": Currently crafting.")
    return
  end
  if (isCpuAvailable(ae2) == false) then
    print(stockSetting.displayName .. ": No crafting CPU available to craft.")
    return
  end
 
  local neededAmount = math.ceil((stockSetting.minQuantity - currItem.size) / stockSetting.batchSize) * stockSetting.batchSize
 
  ae2.requestCrafting(currItem.fingerprint, neededAmount)
  delayItem(currItem.fingerprint, delayedItems)
  print("[" .. getDisplayTime() .. "] Item " .. stockSetting.displayName ..
          " is below its min stock level of " .. stockSetting.minQuantity .. ".  Crafting " .. neededAmount .. " more.")
end
 
function getDisplayTime()
  return os.date("%H:%M:%S", os.time())
end
 
function delayItem(fingerprint, delayedItems)
  local fullItemName = fingerprintToFullName(fingerprint)
 
  if(delayedItems == nil) then
    delayedItems = {}
  end
 
  for i=1, #delayedItems do
    if (delayedItems[i].fullName == fullItemName) then
      delayedItems[i].delay = recraftDelay
      return
    end
  end
 
  local delayedItem = {fullName = fullItemName, delay = recraftDelay}
  delayedItems[#delayedItems+1] = delayedItem
end
 
function updateDelayedItems(delayedItems)
  if (delayedItems == nil or #delayedItems < 1) then return end
 
  local removeIndexes = {}
  for i=1, #delayedItems do
    currItem = delayedItems[i]
    currItem.delay = currItem.delay - checkFrequency
    if (currItem.delay < 0) then
      table.insert(removeIndexes, i)
    end
  end
 
  -- This should remove items from the end of the list towards the beginning
  -- so the list being reordered won't matter.
  for i=1, #removeIndexes do
    table.remove(delayedItems, removeIndexes[i])
  end
end
 
function fingerprintToFullName(fingerprint)
  return fingerprint.id .. ":" .. fingerprint.dmg
end
 
function isDelayed(fingerprint, delayedItems)
  if (delayedItems == nil or #delayedItems < 1) then return false end
 
  local fullItemName = fingerprintToFullName(fingerprint)
  for i=1, #delayedItems do
    if (delayedItems[i].fullName == fullItemName and delayedItems[i].delay > 0) then
      return true
    end
  end
 
  return false
end
 
--function enableAutoRestart()
--  -- Skip this if any startup file already exists.
--  -- Let the user manaully delete or edit the startup file at that point.
--  -- Notify the user.
--  if (fs.exists("startup") == true) then
--    print("Startup file already exists.")
--    return
--  end
-- 
--  outputFile = io.open("startup", "w")
-- 
--  -- Write an info message so that people know how to get out of auto-resume
--  outputFile.write("\nprint(\"Running auto-restart...\")\n")
--  outputFile.write("print(\"If you want to stop auto-resume and restore original state:\")\n")
--  outputFile.write("print(\"1) Hold Ctrl-T until the program terminates\")\n")
--  outputFile.write("print(\"2) Type \\\"rm startup\\\" (without quotes) and hit Enter\")\n")
--  outputFile.write("print(\"\")\n\n")
-- 
--  -- Write the code required to restart the turtle
--  outputFile.write("shell.run(\"")
--  outputFile.write(shell.getRunningProgram())
--  outputFile.write("\")\n")
--  outputFile.close()
--end
 
-- Start the actual program
 
ae2 = attachToAe2()
 
local ok, err = xpcall(main, debug.traceback, args)
if not ok then
  print("Error detected; destroying timer object.")
  event.cancel(timerEvent)
  print(err)
end
 
-- On exit
event.cancel(timerEvent)
print("Stopping autostock system.")
