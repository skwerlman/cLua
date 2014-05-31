
local logName = CLUA_HOME..'/clua.log'

if fs.exists(logName) then
  fs.move(logName, logName..'.old')
end

local tArg = { ... }

local inFileName = tArg[1]
local outFileName = tArg[2] -- We wait to open this so we don't lock the file on crash/terminate
local doLog = tArg[3] and true or false -- clean up tArg[3] so it's always boolean

local function log(msg, tag)
  if doLog then
    tag = tag or (msg and '[OKAY]' or '[ERROR]')
    msg = msg or 'No message passed to log!'
    logFile = fs.open(logName, 'a')
    logFile.writeLine('['..os.time()..']'..tag..msg)
    logFile.close()
  end
  print(msg)
end

log('Enable logging: '..tostring(doLog), '[DEBUG]')

log('Building source table from '..inFileName..'...')
local tSrc = {}
local inFile = fs.open(inFileName, 'r')
while true do
  local line = inFile.readLine()
  if not line then break end
  tSrc[#tSrc+1] = line
end
inFile.close()

--handle #IFNDEF & #ENDIFNDEF



--handle #INCLUDE



--write parsed source table to output file
log('Writing source table to '..outFileName..'...')
local outFile = fs.open(outFileName, 'w')
for _,line in ipairs(tSrc) do
  outFile.writeLine(line)
end
outFile.close()
log('Done.', '[OKAY]')