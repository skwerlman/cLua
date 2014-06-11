local st = os.time()

local tArg = { ... }

if #tArg < 2 then
  return print('CLua '..(CLUA_VERSION or 'MISSING_VERSION_INFO')..' Copyright 2014 Skwerlman\nUsage: clua <input> <output>\nAdd any third argument to enable logging.')
end

local inFileName = tArg[1]
local outFileName = tArg[2]
table.remove(tArg, 1)
table.remove(tArg, 1)

local DEFINE = {}
local WARNLOOP = {}
local doLog = false

--handle args
for k,v in ipairs(tArg) do
  --Undocumented; pending safety tests
  if v:sub(3,6) == 'exec' then
    loadstring(v:sub(8):gsub('++', ' ')..' return true')()

  elseif v:sub(3) == 'log' then
    doLog = true

  elseif v:sub(3,8) == 'define' then
    DEFINE[v:sub(10)] = {'cmd', k}
  
  else
    error('Bad argument: '..v,0)
  end
end

doLog = doLog and true or false

if doLog then
  if fs.exists(CLUA_LOG) then
    if fs.exists(CLUA_LOG..'.old') then
      fs.delete(CLUA_LOG..'.old')
    end
    fs.move(CLUA_LOG, CLUA_LOG..'.old')
  end
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

log('Enable logging: '..tostring(doLog), '[OKAY]')

local function fileToTable(path)
  log('Building source table from '..path..'...', '[DEBUG]', true)
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

local function concat(t1, t2) -- concatenates two source tables
  for i=1,#t2 do
    t1[#t1+1] = t2[i]
    os.queueEvent('null', 'clua') -- avoid crashes in massive files
    os.pullEvent()
  end
  return t1
end

local function parseFile(path)
  local LINENUM = 0
  local function parseLines(file, path)
    local fileOut = {}
    for curLine, line in ipairs(file) do
      LINENUM = LINENUM + 1
      --log(LINENUM..': '..line, '[BUGFIXING]', true)
      if line:byte(1) == 35 then -- don't ever indent directives, unless you like syntax errors
        log('Attempting to handle "'..line..'" on line '..LINENUM, '[DEBUG]', true)

        while true do
          if line:byte(-1) ~= 32 and line:byte(-1) ~= 9 then break end
          line = line:sub(1,-2)
        end

        if line:sub(1, 9) == '#INCLUDE ' then
          --log('#INCLUDE', '[BUGFIXING]', true)
          line = line:gsub('~', CLUA_LIB)
          local i = line:find(' FROM ')
          assert(i, '#INCLUDE had no matching FROM at line '..LINENUM..' in '..path)
          local pt = line:sub(i+6)
          assert(fs.exists(pt), 'INCLUDE directive pointed to non-existant folder on line '..LINENUM..' in '..path)
          assert(fs.isDir(pt), 'INCLUDE-FROM directive pointed to a file instead of a folder on line '..LINENUM..' in '..path)
          local fn = line:sub(10,i-1)
          assert(fs.exists(fs.combine(pt, fn)), 'INCLUDE directive pointed to a non-existant file on line '..LINENUM..' in '..path)
          local fo = parseFile(fs.combine(pt, fn))
          fileOut = concat(fileOut, fo)
          --LINENUM = LINENUM + 1

        elseif line:sub(1, 8) == '#DEFINE ' then
          --log('#DEFINE', '[BUGFIXING]', true)
          local name = line:sub(9)
          if DEFINE[name] then
            if DEFINE[name][1] == path then
              if DEFINE[name][2] == curLine then
                if DEFINE[name] == WARNLOOP[name] then
                  assert(false, 'Infinite loop detected!')
                else
                  log('Potential infinite loop detected!', '[WARNING]')
                  log('Setting warning flag', '[WARNING]')
                  WARNLOOP[name] = DEFINE[name]
                end
              else
                log('Duplicated #DEFINE in '..path..' at lines '..DEFINE[name][2]..' and '..LINENUM, '[WARNING]')
              end
            else
              log('Duplicated #DEFINE in '..DEFINE[name][1]..' at line '..DEFINE[name][2]..' and in '..path..' at line '..LINENUM, '[WARNING]')
            end
            log('#DEFINE directive ignored', '[WARNING]')
          else
            DEFINE[name] = {path, LINENUM}
            log('Defined "'..name..'"', '[DEBUG]', true)
          end

        elseif line == '#SNIPPET' then -- ignore all directives until the end of the file
          --log('#SNIPPET', '[BUGFIXING]', true)
          log('Handling '..path..' as a snippet...', '[OKAY]')
          table.remove(file, curLine) -- remove #SNIPPET directive so we don't warn about 'ignoring' it
          while true do
            local tl = file[curLine]
            if not tl then break end
            if tl:byte(1) ~= 35 then -- if line doesn't start with #, put it in the output table
              fileOut[#fileOut+1] = tl
            else -- directives should never be in snippets, so this is logged as a warning 
              log('Ignoring directive in snippet: '..tl, '[WARNING]')
            end
            table.remove(file, curLine)
          end

        elseif line:sub(1, 7) == '#IFDEF ' then
          --log('#IFDEF', '[BUGFIXING]', true)
          local name = line:sub(8)
          local ft = {}
          while true do
            local tl = file[curLine]
            --log('removing '..tl, '[BUGFIXING]', true)
            table.remove(file, curLine)
            if tl == '#ENDIFDEF' then table.insert(file, 1, '') LINENUM = LINENUM + 1 break end
            ft[#ft+1] = tl
            --log('Table ft:\n'..textutils.serialize(ft), '[BUGFIXING]', true)
            --log('Table file:\n'..textutils.serialize(ft), '[BUGFIXING]', true)
            if curLine == #file then
              assert(false, 'No matching #ENDIFDEF found for #IFDEF on line '..LINENUM..' in '..path) 
            end
          end
          if DEFINE[name] then
            log('Definition found for '..name, '[DEBUG]', true)
            --log('!!removing '..ft[1], '[BUGFIXING]', true)
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log('No definition found for '..name, '[DEBUG]', true)
            LINENUM = LINENUM + #ft - 1
          end

        elseif line:sub(1, 8) == '#IFNDEF ' then
          --log('#IFNDEF', '[BUGFIXING]', true)
          local name = line:sub(9)
          local ft = {}
          while true do
            local tl = file[curLine]
            --log('removing '..tl, '[BUGFIXING]', true)
            table.remove(file, curLine)
            if tl == '#ENDIFNDEF' then table.insert(file, 1, '') LINENUM = LINENUM + 1 break end
            ft[#ft+1] = tl
            --log('Table ft:\n'..textutils.serialize(ft), '[BUGFIXING]', true)
            --log('Table file:\n'..textutils.serialize(ft), '[BUGFIXING]', true)
            if curLine == #file then
              assert(false, 'No matching #ENDIFNDEF found for #IFNDEF on line '..LINENUM..' in '..path) 
            end
          end
          if not DEFINE[name] then
            log('No definition found for '..name, '[DEBUG]', true)
            --log('!!removing '..ft[1], '[BUGFIXING]', true)
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log('Definition found for '..name, '[DEBUG]', true)
            LINENUM = LINENUM + #ft - 1
          end

        elseif line:sub(1, 5) == '#ELSE' then
          assert(false, 'Orphaned #ELSE on line '..LINENUM..' in '..path) -- always error since #ELSEs should be absorbed by #IFDEF or #IFNDEF

        elseif line:sub(1, 8) == '#ELSEIF ' then
          assert(false, 'Orphaned #ELSEIF on line '..LINENUM..' in '..path) -- always error since #ELSEIFs should be absorbed by #IFDEF or #IFNDEF

        elseif line:sub(1, 9) == '#ELSEIFN ' then
          assert(false, 'Orphaned #ELSEIFN on line '..LINENUM..' in '..path) -- always error since #ELSEIFNs should be absorbed by #IFDEF or #IFNDEF

        elseif line == '#ENDIFDEF' then
          assert(false, 'Orphaned #ENDIFDEF on line '..LINENUM..' in '..path) -- always error since #ENDIFDEFs should be absorbed by #IFDEF

        elseif line == '#ENDIFNDEF' then
          assert(false, 'Orphaned #ENDIFNDEF on line '..LINENUM..' in '..path) -- always error since #ENDIFNDEFs should be absorbed by #IFNDEF

        else -- line starts with #, but isn't a directive
          assert(false, 'Invalid preprocessor directive on line '..LINENUM..' in '..path..': '..line)
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
    log('Ignoring line '..ln..' because it\'s empty', '[DEBUG]', true)
    trimCount = trimCount+1
  end
end
outFile.close()
log('Trimmed '..trimCount..' lines from '..outFileName, '[DEBUG]', true)
log('Compilation complete', '[DONE]')
local et = os.time()
log('Time: '..(et-st), '[DONE]')
