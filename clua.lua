local function main(...)
  --PHASE: init
  local st = os.clock()
  local DEFINE, WARNLOOP, VAR, LICENSES, licensePath, tArg, inFileName, outFileName, doLog, dryRun, doRS, quiet, silent, verbose, devel, nodebug, execEnv

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
  --exec:<code>   - Executes arbitrary code before
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

  local function clockAsString()
    local time = os.clock()
    local int, frac = math.modf(time)
    frac = tostring(frac):sub(3)
    if #frac > 8 then -- workaround for massive LuaJ rounding bug (returns stuff like 0.796432E-11 instead of 0)
      frac = '00'
    end
    if #frac > 2 then -- workaround for apparent bug in how times are calculated
      frac = frac:sub(1,2)
    end
    return tostring(int)..'.'..frac..string.rep('0', math.max(0, 2-#frac))
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
    msg = tostring(msg)
    if not noPrint then
      if (silent or quiet) and (tag == '[ERROR]' or tag == '[DONE]') then
        print(msg)
      elseif quiet and tag == '[WARNING]' then
        print(msg)
      elseif not silent and not quiet then
        print(msg)
      end
    end
    if doRS then -- if you'd like to use this for whatever, run with '--rs'
      if tag == '[ERROR]' then rs.setOutput('right', true)
      elseif tag == '[WARNING]' then rs.setOutput('left', true)
      elseif tag =='[DONE]' then rs.setOutput('top', true) end
    end
    if doLog then
      local logFile = fs.open(CLUA_LOG, 'a')
      tag = tag..string.rep(' ', math.max(0, 9-#tag))
      msg = '['..clockAsString()..']'..tag..' '..msg:gsub('\n', '\n['..clockAsString()..']'..tag..' ')
      logFile.writeLine(msg)
      logFile.close()
    end
  end

  local function assert(bool, msg)
    if not bool then
      msg = msg:gsub('\n', '\n> ')
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

  local function tokenize(str, delim, preserveFormatting)
    assert(type(str)=='string', 'bad argument #1: expected string, got'..type(str))
    assert(type(delim)=='string' or type(delim)=='nil', 'bad argument #2: expected string or nil, got'..type(str))
    delim = delim or ' '
    log('Trying to tokenize "'..str..'"', '[DEVEL]', true)
    local tokens = {}
    while true do
      i = str:find(delim)
      if not i then tokens[#tokens+1] = str break end
      tokens[#tokens+1] = str:sub(1,i-1)
      str = str:sub(i+1)
    end
    for k,v in ipairs(tokens) do
      tokens[k] = v:gsub('++', ' ')
      if v == '' and not preserveFormatting then
        table.remove(tokens, k)
      end
    end
    log(textutils.serialize(tokens), '[DEVEL]', true)
    return tokens
  end

  local function fname(path)
    assert(type(path)=='string', 'expected string, got '..type(path))
    local tokens = tokenize(path, '/')
    local filename = tokens[#tokens]
    log('fname: '..path..' ===> '..filename, '[DEVEL]', true)
    return filename
  end

  local function fpath(path)
    assert(type(path)=='string', 'expected string, got '..type(path))
    local tokens = tokenize(path, '/')
    local path2 = ''
    for i=1,#tokens-1 do
      path2 = path2..'/'..tokens[i]
    end
    log('fname: '..path..' ===> '..path2, '[DEVEL]', true)
    return path2
  end

  local function concat(table1, table2, dontLog) -- concatenates two tables, overwriting duplicate non-integer keys with the values from table2
    if not dontLog then
      log('Appending source tables...', '[DEBUG]', true)
    end
    if table2 then
      for k,v in pairs(table2) do
        if type(k) ~= 'number' then
          table1[k] = v
        else
          table.insert(table1, table.maxn(table1)+1, v)
        end
        os.queueEvent('clua') -- avoid crashes in massive files
        os.pullEvent('clua')
      end
    else
      log('concat got a nil second arg instead of a table\nReturning first arg','[WARNING]')
    end
    if not dontLog then
      log('Done.', '[DEBUG]', true)
    end
    return table1
  end

  local function parseFile(path, setModule)
    local LINENUM = 0
    local function parseLines(file, path, setModule)
      local fileOut = {}
      for curLine, line in ipairs(file) do
        if setModule then
          VAR.MODULE = setModule
        else
          VAR.MODULE = fname(path) -- set this each line b/c scopes are wierd
        end
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

          elseif line:sub(1, 15) == '#SETDYNAMICVAR ' then
            log('#SETDYNAMICVAR', '[DEVEL]', true)
            local lt = tokenize(line:sub(16))
            for k,v in ipairs(lt) do
              local d = v:find(':')
              assert(d, '#SETDYNAMICVAR on line '..LINENUM..' in '..path..' contained an\ninvalid VAR:DEF structure')
              VAR[v:sub(1, d-1)] = v:sub(d+1)
            end
            log('Table VAR:\n'..textutils.serialize(VAR), '[DEVEL]', true)

          elseif line:sub(1, 17) == '#DYNAMIC-INCLUDE ' then
            log('#DYNAMIC-INCLUDE', '[DEVEL]', true)
            local lt = tokenize(line:sub(18), ' ', true) -- we want to preserve fomatting here, so we override table trimming
            local d1 = lt[1]
            table.remove(lt, 1)
            local d2 = lt[1]
            table.remove(lt, 1)
            local fo = ''
            for _,v in ipairs(lt) do
              while v:find(d1) and v:find(d2) do
                local oldV = v
                local dloc1 = v:find(d1)
                local dloc2 = v:find(d2)
                local pre = v:sub(1, dloc1-1)
                local post = v:sub(dloc2+1)
                local var = v:sub(dloc1+1, dloc2-#v-2)
                v = VAR[var] or ''
                if v == '' then
                  log('Dynamic variable '..var..' had no definition\nwhen encountered on line '..LINENUM..' in '..path, '[WARNING]')
                end
                v = pre..v..post
                log(oldV..' ===> '..v, '[DEVEL]', true)
              end
              if fo ~= '' then
                v = ' '..v
              end
              fo = fo..v
            end
            log('"'..fo..'"', '[DEVEL]', true)
            table.insert(fileOut, #fileOut+1, fo)

          elseif line:sub(1, 9) == '#LICENSE ' then
            log('#LICENSE', '[DEVEL]', true)
            local lt = tokenize(line:sub(10))
            assert(not (#lt<1), '#LICENSE directive on line '..LINENUM..' in '..path..' did not specify a license')
            local p = lt[1]
            table.remove(lt, 1)
            for k,v in ipairs(lt) do
              local d = v:find(':')
              assert(d, '#LICENSE on line '..LINENUM..' in '..path..' contained an\ninvalid VAR:DEF structure')
              VAR[v:sub(1, d-1)] = v:sub(d+1)
            end
            log('Table VAR:\n'..textutils.serialize(VAR), '[DEVEL]', true)
            if LICENSES[VAR.MODULE] then
              assert(not LICENSES[VAR.MODULE].isLicensed, VAR.MODULE..' already has a license')
            else
              LICENSES[VAR.MODULE] = {}
            end
            LICENSES[VAR.MODULE].isLicensed = p
            log('Table LICENSES:\n'..textutils.serialize(LICENSES), '[DEVEL]', true)
            local fn = fs.combine(CLUA_LIB..'/LICENSE', p)
            log(fn, '[DEVEL]', true)
            assert(fs.exists(fn), '#LICENSE pointed to a non-existant file on line '..LINENUM..' in '..path)
            assert(not fs.isDir(fn), '#LICENSE pointed to a folder instead of a file on line '..LINENUM..' in '..path)
            local fo = parseFile(fn, VAR.MODULE)
            if not dryRun then
              --write parsed source table to output file
              log('Writing source table to '..licensePath..'...')
              local outFile = fs.open(licensePath, 'a')
              for ln,line in ipairs(fo) do
                outFile.writeLine(line)
              end
              outFile.close()
            end
            log('Successfully licensed '..fn)

          elseif line:sub(1, 8) == '#DEFINE ' then
            log('#DEFINE', '[DEVEL]', true)
            log(curLine, '[DEVEL]', true)
            local name = line:sub(9)
            if DEFINE[name] then
              if DEFINE[name][1] == path then
                if DEFINE[name][2] == LINENUM then
                  if DEFINE[name] == WARNLOOP[name] then
                    assert(false, 'Infinite loop detected!')
                  else
                    log('Potential infinite loop detected on line '..LINENUM..' in '..path..'!', '[WARNING]')
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
            log('Table DEFINE:\n'..textutils.serialize(DEFINE), '[DEVEL]', true)
            log('Table WARNLOOP:\n'..textutils.serialize(WARNLOOP), '[DEVEL]', true)

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
            local func, data = loadstring(line:sub(7)..' return true') -- append return true so if they do something without a return value, we don't break
            assert(func, type(data) == 'string' and errmsg..'\n'..data or errmsg..'\nNo error message available')
            setfenv(func,execEnv)
            local ret, err = pcall(func)
            --execEnv=getfenv(func)
            assert(ret, type(err) == 'string' and errmsg..'\n'..data or errmsg..'\nNo error message available')

          elseif line:sub(1,7) == '#IFVAR ' then
            log('#IFVAR', '[DEVEL]', true)
            local name = line:sub(8)
            local ft = {}
            local ol = LINENUM
            while true do
              local tl = file[curLine]
              log('removing '..tl, '[DEVEL]', true)
              table.remove(file, curLine)
              if tl == '#ENDIFVAR' then table.insert(file, 1, '') break end
              ft[#ft+1] = tl
              log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
              log('Table file:\n'..textutils.serialize(file), '[DEVEL]', true)
              if curLine > #file then
                assert(false, 'No matching #ENDIFVAR found for #IFVAR on line '..LINENUM..' in '..path) 
              end
            end
            local errmsg = 'IFVAR directive at line '..ol..' in '..path..' threw an error.'
            local ret, data = loadstring('return '..name)
            assert(ret, type(data) == 'string' and errmsg..'\n'..data or errmsg..'\nNo error message available')
            local val = ret
            setfenv(ret,execEnv)
            ret, data = pcall(ret)
            assert(ret, type(data) == 'string' and errmsg..'\n'..data or errmsg..'\nNo error message available')
            ret = val()
            --execEnv=getfenv(val)
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
              LINENUM = LINENUM + #ft
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
              if tl == '#ENDIFNVAR' then table.insert(file, 1, '') break end
              ft[#ft+1] = tl
              log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
              log('Table file:\n'..textutils.serialize(file), '[DEVEL]', true)
              if curLine > #file then
                assert(false, 'No matching #ENDIFNVAR found for #IFNVAR on line '..LINENUM..' in '..path) 
              end
            end
            local errmsg = 'IFNVAR directive at line '..ol..' in '..path..' threw an error.'
            local ret, data = loadstring('return '..name)
            assert(ret, type(data) == 'string' and errmsg..'\n'..data or errmsg..'\nNo error message available')
            local val = ret
            setfenv(ret,execEnv)
            ret, data = pcall(ret)
            assert(ret, type(data) == 'string' and errmsg..'\n'..data or errmsg..'\nNo error message available')
            ret = val()
            --execEnv=getfenv(val)
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
              LINENUM = LINENUM + #ft
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
              log('Table file:\n'..textutils.serialize(file), '[DEVEL]', true)
              if tl == '#ENDIFDEF' then table.insert(file, 1, '') break end
              ft[#ft+1] = tl
              log('curLine: '..curLine, '[DEVEL]', true)
              log('LINENUM: '..LINENUM, '[DEVEL]', true)
              log('#file: '..#file, '[DEVEL]', true)
              if curLine > #file then
                assert(false, 'No matching #ENDIFDEF found for #IFDEF on line '..LINENUM..' in '..path) 
              end
            end
            log('curLine: '..curLine, '[DEVEL]', true)
            log('LINENUM: '..LINENUM, '[DEVEL]', true)
            log('#file: '..#file, '[DEVEL]', true)
            log('Table ft:\n'..textutils.serialize(ft), '[DEVEL]', true)
            log('Table file:\n'..textutils.serialize(file), '[DEVEL]', true)
            if DEFINE[name] then
              log('Definition found for '..name, '[DEBUG]', true)
              log('removing '..ft[1]..' from ft', '[DEVEL]', true)
              table.remove(ft, 1)
              local fo = parseLines(ft, path)
              fileOut = concat(fileOut, fo)
            else
              log('No definition found for '..name, '[DEBUG]', true)
              LINENUM = LINENUM + #ft
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
              log('Table file:\n'..textutils.serialize(file), '[DEVEL]', true) 
              if tl == '#ENDIFNDEF' then table.insert(file, 1, '')  break end
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
            log('Table file:\n'..textutils.serialize(file), '[DEVEL]', true) 
            if not DEFINE[name] then 
              log('No definition found for '..name, '[DEBUG]', true) 
              log('removing '..ft[1]..' from ft', '[DEVEL]', true) 
              table.remove(ft, 1)
              local fo = parseLines(ft, path)
              fileOut = concat(fileOut, fo)
            else 
              log('Definition found for '..name, '[DEBUG]', true)
              LINENUM = LINENUM + #ft
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
    local fileOut = parseLines(fileToTable(path), path, setModule)
    log('End parsing '..path)
    return fileOut
  end

  --PHASE: preparse
  doLog = false
  dryRun = false
  DEFINE = {}
  WARNLOOP = {}
  VAR = {}
  LICENSES = {}

  --expose certain internals (read-only) to code called by --exec:, #EXEC, #IFVAR, and #IFNVAR
  execEnv=concat(_G,{log=log,doLog=doLog,doRS=doRS,quiet=quiet,silent=silent,verbose=verbose,devel=devel,nodebug=nodebug,assert=assert})

  --handle args
  tArg = { ... }
  local nFiles = 0
  for k,v in ipairs(tArg) do
    if v:sub(1,2) == '--' then
      v = v:sub(3)
      if v:sub(1,4) == 'exec' then
        local errmsg = 'Option exec (#'..k..') caused an error.'
        local func, err = loadstring(v:sub(6):gsub('++',' ')..' return true') -- append return true so if they do something without a return value, we don't break
        assert(func, type(err) == 'string' and errmsg..'\n'..err or errmsg..'\nNo error message available')
        setfenv(func,execEnv)
        local ret, data = pcall(func)
        --execEnv=concat(execEnv, getfenv(func), true)
        assert(ret, type(data) == 'string' and errmsg..'\n'..data or errmsg..'\nNo error message available')

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
        shell.run('pastebin', 'get zPMasvZ2 '..CLUA_HOME..'temp-clua-updater')
        return shell.run(CLUA_HOME..'temp-clua-updater') -- will remove itself post-install

      else
        assert(false, 'Bad option #'..k..': '..v..'\nUnknown option')
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
        assert(false, 'Bad option #'..k..': '..v..'\nToo many files')
      end
      nFiles = nFiles + 1
    end
    --update env for exec each iter
    execEnv=concat(_G,{log=log,doLog=doLog,doRS=doRS,quiet=quiet,silent=silent,verbose=verbose,devel=devel,nodebug=nodebug,assert=assert}, true)
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

  licensePath = outFileName..'.licensing'

  if CLUA_VERSION then
    log('CLua '..CLUA_VERSION, '[OKAY]', true)
  else
    log('CLua is missing it\'s version info!\nDid you modify /startup?', '[WARNING]')
    sleep(.2)
  end
  log('Enable logging: '..tostring(doLog), '[DEBUG]')
  assert(CLUA_LIB, 'CLUA_LIB is nil!\nCannot find library location!\nDid you modify /startup?')

  if fs.exists(licensePath) then
    assert(not fs.isDir(licensePath), licensePath..' is a directory')
    fs.delete(licensePath)
  end

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
end

local args = {...}
local _, err = pcall(function() main(unpack(args)) end)
if err then
  term.clear()
  term.setCursorPos(1, 2)
  print(' CLua '..(CLUA_VERSION or 'MISSING_VERSION_INFO')..' Copyright 2014 Skwerlman\n')
  print(' An Error Has Occured! \n\n')
  printError(' '..tostring(err):gsub('\n','\n ')..'\n\n')
  print(' '..(CLUA_LOG or 'clua.log')..' may contain more info.\n')
  print(' Please wait...\n')
  sleep(3)
end
