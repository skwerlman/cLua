local version = '1.4.0'
local isDebug = false -- set to true to if you like to live on the edge!
local logName = '/clua-install.log'
local success = true
local failReasons = {}
if fs.exists(logName) then
  if fs.exists(logName..'.old') then
    fs.delete(logName..'.old')
  end
  fs.move(logName, logName..'.old')
end
local function log(msg, tag)
  tag = tag or (msg and '[OKAY]' or '[ERROR]')
  msg = msg or 'No message passed to log!'
  logFile = fs.open(logName, 'a')
  logFile.writeLine('['..os.time()..']'..tag..msg)
  logFile.close()
  print(msg)
end
log("http: "..tostring(http and true or false), http and '[OKAY]' or '[ERROR]')
assert(http, "You'll need http enabled to install CLua.")
local install_directory
local msg = "Where would you like to install CLua?"
if not CLUA_HOME then -- first install
  while true do
    print(msg)
    install_directory = read()
    if fs.isDir(install_directory) then break end
    msg = ""
    print("The path you provided doesn't exist. Would you like to create it? (Y/n)")
    local ans = read()
    if ans == 'y' or ans == 'Y' or ans == '' then
      fs.makeDir(install_directory)
      break
    else
      msg = "Please enter the location where you'd like CLua to be installed:"
    end
  end
else
  install_directory = CLUA_HOME
end
if install_directory:byte(-1) ~= 47 then
  install_directory = install_directory..'/'
end
fs.makeDir(fs.combine(install_directory, '/lib'))
local install_message = "-- FILE MODIFIED BY CLUA-INSTALL"
log('Creating startup if not exist...')
local tSrc = {}
local inFile
if fs.exists('/startup') and fs.isDir('/startup') then
  error('/startup is a directory, not a file! Cannot install CLua!',0)
elseif fs.exists('/startup') then
  inFile = fs.open('/startup', 'r')
else
  inFile = fs.open('/startup', 'w')
  inFile.write('')
  inFile.close()
  install_message = '-- FILE AUTOMATICALLY GENERATED BY CLUA-INSTALL'
  inFile = fs.open('/startup', 'r')
end
log('Building source table from startup...')
while true do
  local line = inFile.readLine()
  if not line then break end
  if line == '-- BEGIN CLUA GLOBALS' then -- ignore old globals
    while true do
      line = inFile.readLine()
      if not line then
        printError('ERROR: Found broken CLUA globals which')
        printError('ERROR:   will require manual cleaning.')
        printError('ERROR: Aborting install.')
        return
      end
      if line == "-- END CLUA GLOBALS" then
        line = inFile.readLine()
        break
      end
    end
  end
  tSrc[#tSrc+1] = line
end
inFile.close()
log('Injecting CLua globals into source table...')
table.insert(tSrc, 1, "-- END CLUA GLOBALS")
table.insert(tSrc, 1, "end")
table.insert(tSrc, 1, "  fs.delete(CLUA_HOME..'/temp-clua-updater')")
table.insert(tSrc, 1, "if fs.exists(CLUA_HOME..'/temp-clua-updater') then")
table.insert(tSrc, 1, "shell.setAlias('clua', CLUA)")
--table.insert(tSrc, 1, "_G.CLUA_LUAMAN = "..tostring(man and true or false)) -- For LuaMan integration
table.insert(tSrc, 1, "_G.CLUA_LOG = CLUA_HOME..'clua.log'")
--table.insert(tSrc, 1, "_G.CLUA_LIB_LIST = {}")
table.insert(tSrc, 1, "_G.CLUA_LIB = CLUA_HOME..'lib'")
table.insert(tSrc, 1, "_G.CLUA = CLUA_HOME..'clua.lua'")
table.insert(tSrc, 1, "_G.CLUA_HOME = '"..install_directory.."'")
table.insert(tSrc, 1, "_G.CLUA_VERSION = '"..version.."'")
table.insert(tSrc, 1, "-- CLua Copyright 2014 Skwerlman")
table.insert(tSrc, 1, install_message)
table.insert(tSrc, 1, "-- BEGIN CLUA GLOBALS")
log('Constructing startup from source table...')
local outFile = fs.open('/startup', 'w')
for _,line in ipairs(tSrc) do
  outFile.writeLine(line)
end
outFile.close()
log('Beginning downloader...')
log('isDebug:'..tostring(isDebug), '[DEBUG]')
local tFiles = {
    'clua.lua',
    'LICENSE',
    'lib/CRC32',
    'lib/LUABIT',
    'lib/SPLASH',
    'lib/JSON'
  }
local repo = 'https://raw.github.com/skwerlman/Clua/master/'
if isDebug then -- use dev repo instead
  repo = 'https://raw.github.com/skwerlman/Clua/dev/'
end
for i = 1, #tFiles do
  local sFile = tFiles[i]
  local sResponse
  --log('Downloading '..sFile..' from '..repo..'...')
  local response = http.get(repo..sFile, {['User-Agent'] = 'CLua-install Autodownloader'})
  if response then
    if response.getResponseCode() == 200 then
      sResponse = response.readAll()
    else
      success = false
      failReasons[#failReasons+1] = "Unexpected response code "..response.getResponseCode()
    end
    response.close()
  end
  if sResponse and sResponse ~= '' then
    local handle = fs.open(install_directory..sFile, 'w')
    handle.write(sResponse, 'w')
    handle.close()
    log(repo..sFile..' ===> '..install_directory..sFile, '[OKAY]')
  else
    log(repo..sFile..' =X=> '..install_directory..sFile, '[ERROR]')
    sleep(.3)
    success = false
    failReasons[#failReasons+1] = "Couldn't download "..repo..sFile
  end
end
if success then
  log('Install completed successfully')
else
  log('Install failed.', '[ERROR]')
  log('Reason(s):', '[ERROR]')
  for _,v in ipairs(failReasons) do
    log(v, '[ERROR]')
  end
  print('See clua-install.log for more info')
end
print('Rebooting to apply environment settings...')
sleep(3)
os.reboot()
