-- compiles a test file designed to test all of clua's main features
-- will output two files: output and output.licensing
-- on a successful run, there should be exactly one warning: [WARNING] Ignoring directive in snippet: #EXEC log('test failed', '[ERROR]')
-- we exclude debug messages from the log since test output is either logged under the [OKAY] tag or an error
shell.run('clua','test1 output --in-path:/test/ --to-path:/test/ --log --no-debug --no-trim')
