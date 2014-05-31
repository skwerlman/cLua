
if fs.exists(CLUA_LOG) then
  if fs.exists(CLUA_LOG..'.old') then
    fs.delete(CLUA_LOG..'.old')
  end
  fs.move(CLUA_LOG, CLUA_LOG..'.old')
end

local tArg = { ... }

local inFileName = tArg[1]
local outFileName = tArg[2] -- We wait to open this so we don't lock the file on crash/terminate
local doLog = tArg[3] and true or false -- clean up tArg[3] so it's always boolean

local function log(msg, tag, silent)
  if doLog then
    tag = tag or (msg and '[OKAY]' or '[ERROR]')
    msg = msg or 'No message passed to log!'
    logFile = fs.open(CLUA_LOG, 'a')
    logFile.writeLine('['..os.time()..']'..tag..' '..msg)
    logFile.close()
  end
  if not silent then
    print(msg)
  end
end

local function assert(bool, msg)
  if not bool then
    log(msg, '[ERROR]', true)
    error(msg,0)
  end
end

log('Enable logging: '..tostring(doLog), '[DEBUG]')

local function fileToTable(path)
  log('Building source table from '..path..'...')
  local tSrc = {}
  local inFile = fs.open(path, 'r')
  while true do
    local line = inFile.readLine()
    if not line then break end
    tSrc[#tSrc+1] = line
  end
  inFile.close()
  return tSrc
end

local function concat(t1, t2)
  for i=1,#t2 do
    t1[#t1+1] = t2[i]
    os.queueEvent('null')
    os.pullEvent()
  end
  return t1
end

local function parseFile(path) 
  log('Begin parsing '..path..'...')
  file = fileToTable(path)
  local fileOut = {}
  for lineNum, line in ipairs(file) do
    if line:byte(1) == 35 then
      log('Attempting to handle "'..line..'"', '[DEBUG]')
      if line:sub(1, 9) == '#INCLUDE ' then
        --line = line:gsub('~', CLUA_LIB)
        local i = line:find(' FROM ')
        assert(i, '#INCLUDE had no matching FROM at line '..lineNum..' in '..path)
        local pt = line:sub(i+6)
        assert(fs.exists(pt), 'INCLUDE directive pointed to non-existant folder on line '..lineNum..' in '..path)
        assert(fs.isDir(pt), 'INCLUDE-FROM directive pointed to a file instead of a folder on line '..lineNum..' in '..path)
        local fn = line:sub(10,i-1)
        assert(fs.exists(fs.combine(pt, fn)), 'INCLUDE directive pointed to a non-existant file on line '..lineNum..' in '..path)
        local fo = parseFile(fs.combine(pt, fn))
        fileOut = concat(fileOut, fo)
      elseif line:sub(1, 8) == '#DEFINE ' then
        --
      elseif line:sub(1, 8) == '#IFNDEF ' then
        --
      elseif line:sub(1, 10) == '#ENDIFNDEF' then
        --
      else
        assert(false, 'Invalid preprocessor directive on line '..lineNum..' in '..path)
      end
    else
      fileOut[#fileOut+1] = line
    end
  end

  log('End parsing '..path)
  return fileOut
end

local tSrc = parseFile(inFileName)

--write parsed source table to output file
log('Writing source table to '..outFileName..'...')
local outFile = fs.open(outFileName, 'w')
for _,line in ipairs(tSrc) do
  outFile.writeLine(line)
end
outFile.close()

local trimCount = 0

log('Removing blank lines from '..outFileName..'...')
local file = fileToTable(outFileName)
local fileOut = {}
for lineNum, line in ipairs(file) do
  if line ~= '' then
    fileOut[#fileOut+1] = line
  else
    trimCount = trimCount+1
  end
end
log('Writing source table to '..outFileName..'...')
local outFile = fs.open(outFileName, 'w')
for _,line in ipairs(fileOut) do
  outFile.writeLine(line)
end
outFile.close()

log('Trimmed '..trimCount..' lines from '..outFileName)

log('Done.')
