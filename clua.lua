local tArg = { ... }

local inFileName = tArg[1]
local outFileName = tArg[2] -- We wait to open this so we don't lock the file on crash/terminate
local doLog = tArg[3] and true or false -- clean up tArg[3] so it's always boolean

if not (tArg[1] and tArg[2]) then
  return print('CLua '..CLUA_VERSION..' Copyright 2014 Skwerlman\nUsage: clua <input> <output>\nAdd any third argument to enable logging.')
end

if fs.exists(CLUA_LOG) then
  if fs.exists(CLUA_LOG..'.old') then
    fs.delete(CLUA_LOG..'.old')
  end
  fs.move(CLUA_LOG, CLUA_LOG..'.old')
end

local function log(msg, tag, silent)
  if doLog then
    tag = tag or (msg and '[OKAY]' or '[WARNING]')
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
    print('Error encountered')
    log('Terminating job!', '[ERROR]')
    error(msg,0)
  end
end

log('Enable logging: '..tostring(doLog), '[DEBUG]')

local function fileToTable(path)
  log('Building source table from '..path..'...', '[DEBUG]')
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
    os.queueEvent('null') -- avoid crashes in massive files
    os.pullEvent()
  end
  return t1
end

local DEFINE = {}
local WARNLOOP = {}

local function parseFile(path)
  local function parseLines(file, path)
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
          assert(fs.exists(fs.combine(pt, fn)), 'INCLUDE directive pointed to a non-existant file on lin  e '..lineNum..' in '..path)
          local fo = parseFile(fs.combine(pt, fn))
          fileOut = concat(fileOut, fo)

        elseif line:sub(1, 8) == '#DEFINE ' then
          local name = line:sub(9)
          if DEFINE[name] then
            if DEFINE[name][1] == path then
              if DEFINE[name][2] == lineNum then
                if DEFINE[name] == WARNLOOP[name] then
                  assert(false, 'Infite loop detected!')
                else
                  log('Potential infinite loop detected!', '[WARNING]')
                  log('Setting warning flag', '[WARNING]')
                  WARNLOOP[name] = DEFINE[name]
                end
              else
                log('Duplicated #DEFINE in '..path..' at lines '..DEFINE[name][2]..' and '..lineNum, '[WARNING]')
              end
            else
              log('Duplicated #DEFINE in '..DEFINE[name][1]..' at line '..DEFINE[name][2]..' and in '..path..' at line '..lineNum, '[WARNING]')
            end
            log('#DEFINE directive ignored', '[WARNING]')
          else
            DEFINE[name] = {path, lineNum}
            log('Defined "'..name..'"', '[DEBUG]')
          end

        elseif line:sub(1, 7) == '#IFDEF ' then
          local name = line:sub(8)
          local ft = {}
          while true do
            local tl = file[lineNum]
            table.remove(file, lineNum)
            if string.sub(tl, 1, 9) == '#ENDIFDEF' then break end
            ft[#ft+1] = tl
            if lineNum == #file then
              assert(false, 'No matching #ENDIFDEF found for #IFDEF on line '..lineNum..' in '..path) 
            end
          end
          if DEFINE[name] then
            log('Definition found for '..name, '[DEBUG]')
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log('No definition found for '..name, '[DEBUG]')
          end

        elseif line:sub(1, 9) == '#ENDIFDEF' then
          assert(false, 'Orphaned #ENDIFDEF on line '..lineNum..' in '..path) -- always error since #ENDIFDEFs should be absorbed by #IFDEF

        elseif line:sub(1, 8) == '#IFNDEF ' then
          local name = line:sub(9)
          local ft = {}
          while true do
            local tl = file[lineNum]
            table.remove(file, lineNum)
            if string.sub(tl, 1, 10) == '#ENDIFNDEF' then break end
            ft[#ft+1] = tl
            if lineNum == #file then
              assert(false, 'No matching #ENDIFNDEF found for #IFNDEF on line '..lineNum..' in '..path) 
            end
          end
          if not DEFINE[name] then
            log('No definition found for '..name, '[DEBUG]')
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log('Definition found for '..name, '[DEBUG]')
          end

        elseif line:sub(1, 10) == '#ENDIFNDEF' then
          assert(false, 'Orphaned #ENDIFNDEF on line '..lineNum..' in '..path) -- always error since #ENDIFNDEFs should be absorbed by #IFNDEF

        else
          assert(false, 'Invalid preprocessor directive on line '..lineNum..' in '..path)
        end
      else
        fileOut[#fileOut+1] = line
      end
    end
    return fileOut
  end
  log('Begin parsing '..path..'...')
  local fileOut = parseLines(fileToTable(path), path)
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

log('Trimmed '..trimCount..' lines from '..outFileName, '[DEBUG]')

log('Compilation complete', '[DONE]')