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
      if line:byte(1) == 35 then -- don't indent directives
        log('Attempting to handle "'..line..'" on line '..lineNum, '[DEBUG]')

        while true do
          if line:byte(-1) ~= 32 and line:byte(-1) ~= 9 then break end
          line = line:sub(1,-2)
        end

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
                  assert(false, 'Infinite loop detected!')
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
          --log('#IFDEF', '[DEBUG]')
          local name = line:sub(8)
          local ft = {}
          while true do
            local tl = file[lineNum]
            --log('removing '..tl, '[DEBUG]')
            table.remove(file, lineNum)
            if tl == '#ENDIFDEF' then table.insert(file, 1, '') break end
            ft[#ft+1] = tl
            --log('Table ft:\n'..textutils.serialize(ft), '[DEBUG]')
            --log('Table file:\n'..textutils.serialize(ft), '[DEBUG]')
            if lineNum == #file then
              assert(false, 'No matching #ENDIFDEF found for #IFDEF on line '..lineNum..' in '..path) 
            end
          end
          if DEFINE[name] then
            log('Definition found for '..name, '[DEBUG]')
            --log('!!removing '..ft[1], '[DEBUG]')
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log('No definition found for '..name, '[DEBUG]')
          end

        elseif line == '#ENDIFDEF' then
          assert(false, 'Orphaned #ENDIFDEF on line '..lineNum..' in '..path) -- always error since #ENDIFDEFs should be absorbed by #IFDEF

        elseif line:sub(1, 8) == '#IFNDEF ' then
          --log('#IFNDEF', '[DEBUG]')
          local name = line:sub(9)
          local ft = {}
          while true do
            local tl = file[lineNum]
            --log('removing '..tl, '[DEBUG]')
            table.remove(file, lineNum)
            if tl == '#ENDIFNDEF' then table.insert(file, 1, '') break end
            ft[#ft+1] = tl
            --log('Table ft:\n'..textutils.serialize(ft), '[DEBUG]')
            --log('Table file:\n'..textutils.serialize(ft), '[DEBUG]')
            if lineNum == #file then
              assert(false, 'No matching #ENDIFNDEF found for #IFNDEF on line '..lineNum..' in '..path) 
            end
          end
          if not DEFINE[name] then
            log('No definition found for '..name, '[DEBUG]')
            --log('!!removing '..ft[1], '[DEBUG]')
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log('Definition found for '..name, '[DEBUG]')
          end

        elseif line == '#ENDIFNDEF' then
          assert(false, 'Orphaned #ENDIFNDEF on line '..lineNum..' in '..path) -- always error since #ENDIFNDEFs should be absorbed by #IFNDEF

        elseif line:sub(1, 5) == '#ELSE' then -- else (relies on pre)
          --

        elseif line:sub(1, 8) == '#ELSEIF ' then -- else if flag
          --

        elseif line:sub(1, 9) == '#ELSEIFN ' then -- else if not flag
          --

        elseif line == '#SNIPPET' then -- ignore all directives until the end of the file
          log('Handling '..path..' as a snippet...', '[DEBUG]')
          table.remove(file, lineNum) -- remove #SNIPPET directive so we don't warn about 'ignoring' it
          while true do
            local tl = file[lineNum]
            if not tl then break end
            if tl:byte(1) ~= 35 then -- if line doesn't start with #, put it in the output table
              fileOut[#fileOut+1] = tl
            else -- directives should never be in snippets, so this is logged as a warning 
              log('Ignoring directive in snippet: '..tl, '[WARNING]')
            end
            table.remove(file, lineNum)
          end

        else -- line starts with #, but isn't a directive
          assert(false, 'Invalid preprocessor directive on line '..lineNum..' in '..path..': '..line)
        end
      else -- not a directive, so we put it in the output table
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
local trimCount = 0

--write parsed source table to output file
log('Writing source table to '..outFileName..'...')
local outFile = fs.open(outFileName, 'w')
for ln,line in ipairs(tSrc) do
  if line ~= '' then
    outFile.writeLine(line)
  else
    log('Ignoring line '..ln..' because it\'s empty', '[DEBUG]')
    trimCount = trimCount+1
  end
end
outFile.close()
log('Trimmed '..trimCount..' lines from '..outFileName, '[DEBUG]')
log('Compilation complete', '[DONE]')
