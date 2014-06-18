--PHASE: init
local st = os.clock()
local doLog, dryRun, doRS, quiet, silent, verbose, devel, nodebug, DEFINE, WARNLOOP, tArg, inFileName, outFileName

--PHASE: functions
local function printUsage()
  textutils.pagedPrint('CLua '..(CLUA_VERSION or 'MISSING_VERSION_INFO')..[[ Copyright 2014 Skwerlman
Usage:
  clua <input> <output> [--help] [--log]
       [--version] [--dry-run] [--exec:<code> ...]
       [--define:<flag> ...] [--quiet] [--silent]
       [--verbose] [--devel] [--no-debug]

  --help          - Display this help message and
                    exit.
  --log           - Enables logging.  
  --version       - Print version info and exit.
  --dry-run       - Runs through the compilation,
                    but doesn't modify the output
                    file.
  --exec:<code>   - Executes arbitraty code before
                    compilation. Use ++ instead of
                    spaces.
  --define:<flag> - Equivelent to #DEFINE.
  --quiet         - Do not print most messages.
  --silent        - Only print errors.
  --verbose       - Prints ALL messages.
  --devel         - Allows logging of DEVEL level
                    messages. Useful only for
                    debugging. Much slower than
                    normal, especially for large
                    programs. Not recommended.
  --no-debug      - Don't log DEBUG level messages.
  --self-update   - Downloads and runs the latest
                    CLua installer, then reboots.]], 17)
end

local function log(msg, tag, noPrint)
  if verbose then
    noPrint = false
  end
  if not devel and tag == '[DEVEL]' then
    return
  end
  if nodebug and (tag == '[DEBUG]' or tag == '[DEVEL]') then
    return
  end
  tag = tag or (msg and '[OKAY]' or '[WARNING]')
  msg = msg or 'No message passed to log!'
  if not noPrint then
    if (silent or quiet) and (tag == '[ERROR]' or tag == '[DONE]') then
      print(msg)
    elseif quiet and tag == '[WARNING]' then
      print(msg)
    elseif not silent and not quiet then
      print(msg)
    end
  end
  if doLog then
    local logFile = fs.open(CLUA_LOG, 'a')
    msg = '['..os.clock()..']'..tag..' '..msg:gsub('\n', '\n['..os.clock()..']'..tag..' ')
    logFile.writeLine(msg)
    logFile.close()
  end
  if doRS then
    if tag == '[ERROR]' then rs.setOutput('right', true)
    elseif tag == '[WARNING]' then rs.setOutput('left', true)
    elseif tag =='[DONE]' then rs.setOutput('top', true) end
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

local function fileToTable(path)
  assert(fs.exists(path), path..' does not exist!')
  assert(not fs.isDir(path), path..' is a directory!')
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
  log('Appending source tables...', '[DEBUG]', true)
  for i=1,#t2 do
    t1[#t1+1] = t2[i]
    os.queueEvent('clua') -- avoid crashes in massive files
    os.pullEvent('clua')
  end
  log('Done.', '[DEBUG]', true)
  return t1
end

local function parseFile(path)
  local LINENUM = 0
  local function parseLines(file, path)
    local fileOut = {}
    for curLine, line in ipairs(file) do
      LINENUM = LINENUM + 1
      log(path..':'..LINENUM..': '..line, '[DEVEL]', true)
      if line:byte(1) == 35 then -- don't ever indent directives, unless you really like syntax errors
        log('Attempting to handle "'..line..'" on line '..LINENUM, '[DEBUG]', true)

        while true do -- strip trailing whitespace (skipped by #SNIPPET)
          if line:byte(-1) ~= 32 and line:byte(-1) ~= 9 then break end
          line = line:sub(1,-2)
        end

        if line:sub(1, 9) == '#INCLUDE ' then
          log('#INCLUDE', '[DEVEL]', true)
          line = line:gsub('~', CLUA_LIB)
          local i = line:find(' FROM ')
          assert(i, '#INCLUDE had no matching FROM at line '..LINENUM..' in '..path)
          local pt = line:sub(i+6)
          assert(fs.exists(pt), 'FROM pointed to non-existant folder on line '..LINENUM..' in '..path)
          assert(fs.isDir(pt), 'FROM pointed to a file instead of a folder on line '..LINENUM..' in '..path)
          local fn = fs.combine(pt, line:sub(10,i-1))
          assert(fs.exists(fn), '#INCLUDE-FROM pointed to a non-existant file on line '..LINENUM..' in '..path)
          assert(not fs.isDir(fn), '#INCLUDE-FROM pointed to a folder instead of a file on line '..LINENUM..' in '..path)
          local fo = parseFile(fn)
          fileOut = concat(fileOut, fo)
          log('Successfully included '..fn)

        elseif line:sub(1, 8) == '#DEFINE ' then
          log('#DEFINE', '[DEVEL]', true)
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
          log('#SNIPPET', '[DEVEL]', true)
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

        elseif line:sub(1,6) == '#EXEC ' then
          log(line, '[DEVEL]', true)
          local errmsg = 'EXEC directive at line '..LINENUM..' in '..path..' threw an error.'
          local ret, data = loadstring(line:sub(7)..' return true') -- append return true so if they do something without a return value, we don't break
          assert(ret, type(data) == 'string' and errmsg..'\n> '..data:gsub('\n', '\n> ') or errmsg..'\n> No error message available')
          ret, data = pcall(ret)
          assert(ret, type(data) == 'string' and errmsg..'\n> '..data:gsub('\n', '\n> ') or errmsg..'\n> No error message available')

        elseif line:sub(1,7) == '#IFVAR ' then
          log('#IFVAR', '[DEVEL]', true)
          local name = line:sub(8)
          local ft = {}
          local ol = LINENUM
          while true do
            local tl = file[curLine]
            log('removing '..tl, '[DEVEL]', true)
            table.remove(file, curLine)
            if tl == '#ENDIFVAR' then table.insert(file, 1, '') LINENUM = LINENUM + 1 break end
            ft[#ft+1] = tl
            log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
            log('Table file:\n'..textutils.serialize(ft), '[DEVEL]', true)
            if curLine > #file then
              assert(false, 'No matching #ENDIFVAR found for #IFVAR on line '..LINENUM..' in '..path) 
            end
          end
          local errmsg = 'IFVAR directive at line '..ol..' in '..path..' threw an error.'
          local ret, data = loadstring('return '..name)
          assert(ret, type(data) == 'string' and errmsg..'\n> '..data or errmsg..'\n> No error message available')
          local val = ret
          ret, data = pcall(ret)
          assert(ret, type(data) == 'string' and errmsg..'\n> '..data or errmsg..'\n> No error message available')
          ret = val()
          if ret then
            log(name..'=='..tostring(ret), '[DEVEL]', true)
            log('Definition found for '..name, '[DEBUG]', true)
            log('removing '..ft[1], '[DEVEL]', true)
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log(name..'=='..tostring(ret), '[DEVEL]', true)
            log('No definition found for '..name, '[DEBUG]', true)
            LINENUM = LINENUM + #ft - 1
          end
          log('#ENDIFVAR', '[DEVEL]', true)


        elseif line:sub(1,8) == '#IFNVAR ' then
          log('#IFNVAR', '[DEVEL]', true)
          local name = line:sub(8)
          local ft = {}
          local ol = LINENUM
          while true do
            local tl = file[curLine]
            log('removing '..tl, '[DEVEL]', true)
            table.remove(file, curLine)
            if tl == '#ENDIFNVAR' then table.insert(file, 1, '') LINENUM = LINENUM + 1 break end
            ft[#ft+1] = tl
            log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
            log('Table file:\n'..textutils.serialize(ft), '[DEVEL]', true)
            if curLine > #file then
              assert(false, 'No matching #ENDIFNVAR found for #IFNVAR on line '..LINENUM..' in '..path) 
            end
          end
          local errmsg = 'IFNVAR directive at line '..ol..' in '..path..' threw an error.'
          local ret, data = loadstring('return '..name)
          assert(ret, type(data) == 'string' and errmsg..'\n> '..data or errmsg..'\n> No error message available')
          local val = ret
          ret, data = pcall(ret)
          assert(ret, type(data) == 'string' and errmsg..'\n> '..data or errmsg..'\n> No error message available')
          ret = val()
          if not ret then
            log(name..'=='..tostring(ret), '[DEVEL]', true)
            log('Definition found for '..name, '[DEBUG]', true)
            log('removing '..ft[1], '[DEVEL]', true)
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log(name..'=='..tostring(ret), '[DEVEL]', true)
            log('Definition found for '..name, '[DEBUG]', true)
            LINENUM = LINENUM + #ft - 1
          end
          log('#ENDIFNVAR', '[DEVEL]', true)


        elseif line:sub(1, 7) == '#IFDEF ' then
          log('#IFDEF', '[DEVEL]', true)
          local name = line:sub(8)
          local ft = {}
          while true do
            local tl = file[curLine]
            log('removing '..tl..' from file', '[DEVEL]', true)
            table.remove(file, curLine)
            log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
            log('Table file:\n'..textutils.serialize(ft), '[DEVEL]', true)
            if tl == '#ENDIFDEF' then table.insert(file, 1, '') LINENUM = LINENUM + 1 break end
            ft[#ft+1] = tl
            log('curLine: '..curLine, '[DEVEL]', true)
            log('LINENUM: '..LINENUM, '[DEVEL]', true)
            log('#file: '..#file, '[DEVEL]', true)
            if curLine > #file then
              assert(false, 'No matching #ENDIFDEF found for #IFDEF on line '..LINENUM..' in '..path) 
            end
          end
          log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
          log('Table file:\n'..textutils.serialize(ft), '[DEVEL]', true)
          if DEFINE[name] then
            log('Definition found for '..name, '[DEBUG]', true)
            log('removing '..ft[1]..' from ft', '[DEVEL]', true)
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log('No definition found for '..name, '[DEBUG]', true)
            LINENUM = LINENUM + #ft - 1
          end
          log('#ENDIFDEF', '[DEVEL]', true)


        elseif line:sub(1, 8) == '#IFNDEF ' then
          log('#IFNDEF', '[DEVEL]', true)
          local name = line:sub(9)
          local ft = {}
          while true do
            local tl = file[curLine]
            log('removing '..tl..' from file', '[DEVEL]', true)
            table.remove(file, curLine)
            log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
            log('Table file:\n'..textutils.serialize(ft), '[DEVEL]', true)
            if tl == '#ENDIFNDEF' then table.insert(file, 1, '') LINENUM = LINENUM + 1 break end
            ft[#ft+1] = tl
            log('curLine: '..curLine, '[DEVEL]', true)
            log('LINENUM: '..LINENUM, '[DEVEL]', true)
            log('#file: '..#file, '[DEVEL]', true)
            if curLine > #file then
              assert(false, 'No matching #ENDIFNDEF found for #IFNDEF on line '..LINENUM..' in '..path) 
            end
          end
          log('curLine: '..curLine, '[DEVEL]', true)
          log('LINENUM: '..LINENUM, '[DEVEL]', true)
          log('#file: '..#file, '[DEVEL]', true)
          log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
          log('Table file:\n'..textutils.serialize(ft), '[DEVEL]', true)
          if not DEFINE[name] then
            log('No definition found for '..name, '[DEBUG]', true)
            log('removing '..ft[1]..' from ft', '[DEVEL]', true)
            table.remove(ft, 1)
            local fo = parseLines(ft, path)
            fileOut = concat(fileOut, fo)
          else
            log('Definition found for '..name, '[DEBUG]', true)
            LINENUM = LINENUM + #ft - 1
          end
          log('#ENDIFNDEF', '[DEVEL]', true)

        elseif line:sub(1, 5) == '#ELSE' then
          assert(false, 'Orphaned #ELSE on line '..LINENUM..' in '..path) -- always error since #ELSEs should be absorbed by #IFDEF or #IFNDEF

        elseif line:sub(1, 8) == '#ELSEIF ' then
          assert(false, 'Orphaned #ELSEIF on line '..LINENUM..' in '..path) -- always error since #ELSEIFs should be absorbed by #IFDEF or #IFNDEF

        elseif line:sub(1, 9) == '#ELSEIFN ' then
          assert(false, 'Orphaned #ELSEIFN on line '..LINENUM..' in '..path) -- always error since #ELSEIFNs should be absorbed by #IFDEF or #IFNDEF

        elseif line == '#ENDIFVAR' then
          assert(false, 'Orphaned #ENDIFVAR on line '..LINENUM..' in '..path) -- always error since #ENDIFVARs should be absorbed by #IFVAR

        elseif line == '#ENDIFNVAR' then
          assert(false, 'Orphaned #ENDIFNVAR on line '..LINENUM..' in '..path) -- always error since #ENDIFNVARs should be absorbed by #IFNVAR

        elseif line == '#ENDIFDEF' then
          assert(false, 'Orphaned #ENDIFDEF on line '..LINENUM..' in '..path) -- always error since #ENDIFDEFs should be absorbed by #IFDEF

        elseif line == '#ENDIFNDEF' then
          assert(false, 'Orphaned #ENDIFNDEF on line '..LINENUM..' in '..path) -- always error since #ENDIFNDEFs should be absorbed by #IFNDEF

        else -- line starts with #, but isn't a known directive; likely a typo, so we abort
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

--PHASE: preparse
doLog = false
dryRun = false
DEFINE = {}
WARNLOOP = {}

--handle args
tArg = { ... }
local nFiles = 0
for k,v in ipairs(tArg) do
  if v:sub(1,2) == '--' then
    v = v:sub(3)
    if v:sub(1,4) == 'exec' then
      local errmsg = 'Option exec (#'..k..') caused an error.'
      local func, err = loadstring(v:sub(6)..' return true') -- append return true so if they do something without a return value, we don't break
      assert(func, type(err) == 'string' and errmsg..'\n> '..err or errmsg..'\n> No error message available')
      local ret, data = pcall(func)
      assert(ret, type(data) == 'string' and errmsg..'\n> '..data or errmsg..'\n> No error message available')

    elseif v:sub(1,6) == 'define' then
      DEFINE[v:sub(8)] = {'cmd', k}

    elseif v == 'log' then
      doLog = true
      if fs.exists(CLUA_LOG) then
        if fs.exists(CLUA_LOG..'.old') then
          fs.delete(CLUA_LOG..'.old')
        end
        fs.move(CLUA_LOG, CLUA_LOG..'.old')
      end

    elseif v == 'quiet' then
      quiet = true

    elseif v == 'silent' then
      silent = true

    elseif v == 'verbose' then
      verbose = true

    elseif v == 'devel' then
      devel = true

    elseif v == 'no-debug' then
      nodebug = true
    
    elseif v == 'dry-run' then
      dryRun = true

    elseif v == 'rs' then -- Hecka undocumented! Hard to use! Almost pointless! HELL YEAH!
      doRS = true
      rs.setOutput('right', false)
      rs.setOutput('left', false)
      rs.setOutput('top', false)

    elseif v == 'help' then
      return printUsage()

    elseif v == 'version' then
      return print('CLua '..(CLUA_VERSION or 'MISSING_VERSION_INFO')..' Copyright 2014 Skwerlman')

    elseif v == 'self-update' then
      shell.run('pastebin', 'get zPMasvZ2 '..CLUA_HOME..'clua-temp-updater')
      return shell.run(CLUA_HOME..'clua-temp-updater') -- will remove itself post-install

    else
      assert(false, 'Bad argument #'..k..': '..v)
    end
  else
    if v == '-?' then
      return printUsage()
    end
    if nFiles == 0 then
      inFileName = v
    elseif nFiles == 1 then
      outFileName = v
    else
      assert(false, 'Bad argument #'..k..': '..v)
    end
    nFiles = nFiles + 1
  end
end
if not (inFileName and outFileName) then
  return printUsage()
end

if silent then
  quiet = false
  verbose = false
end
if quiet then
  verbose = false
end
if devel then
  nodebug = false
end

log('CLua '..CLUA_VERSION, '[DEBUG]', true)
log('Enable logging: '..tostring(doLog), '[DEBUG]')

--PHASE: parse
local tSrc = parseFile(inFileName)

--PHASE: postparse
if not dryRun then
  --write parsed source table to output file
  log('Writing source table to '..outFileName..'...')
  local trimCount = 0
  local outFile = fs.open(outFileName, 'w')
  for ln,line in ipairs(tSrc) do
    log(outFileName..':'..ln..': '..line, '[DEVEL]', true)
    if line ~= '' then
      outFile.writeLine(line)
    else
      log('Ignoring line '..ln..' because it\'s empty', '[DEBUG]', true)
      trimCount = trimCount+1
    end
  end
  outFile.close()
  log('Trimmed '..trimCount..' lines from '..outFileName, '[DEBUG]', true)
end
log('Compilation complete', '[DONE]')
local et = os.clock()
log('Time: '..math.ceil(20*(et-st))..' tick'..((math.ceil(20*(et-st)) ~= 1) and 's' or '')..' ('..(math.ceil(20*(et-st))/20)..' second'..((math.ceil(20*(et-st)) ~= 20) and 's' or '')..')', '[DONE]')
