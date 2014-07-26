-- compiles a test file designed to test all of clua's main features
-- will output two files: output and output.licensing
-- on a successful run, there should be exactly one warning: [WARNING] Ignoring directive in snippet: #EXEC log('test failed', '[ERROR]')
-- we exclude debug messages from the log since test output is either logged under the [OKAY] tag or an error
shell.run('clua test1 output --from-path:/clua/test/ --to-path:/clua/test/ --log --no-debug --silent')
local _, err = pcall(function() shell.run('/clua/test/output') end)
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
print('See clua.log for test results')