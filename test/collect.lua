local failures = {}
local testspec = { -- Each test consists of a setup file, the main test file, and a timeout in ms.
    -- { "init-lazy.lua", "test-lazy.lua", 10000 },
    { "init-pckr.lua", "test-pckr.lua", 10000 },
}
local tests = require("test.tests")

function runtest(file, cmd, timeout)
    -- The timeout should be able to accomodate all of the vim.defer_fn() calls in the session.
    -- It should be less than the maximum timeout in test/run.lua.
    local job = vim.system(cmd, { timeout = timeout, text = true }):wait()
    if job.code == tests.TERMCODE or job.signal == tests.TERM then
        if #string.gsub(job.stderr, "%s", "") > 0 then
            tests.crit(job.stderr)
        end
        tests.crit("reached the timeout for " .. file)
        return false
    elseif job.code ~= 0 then
        tests.crit(job.stderr)
        return false
    end
    return true
end

for _, spec in pairs(testspec) do
    initfile = spec[1]
    testfile = spec[2]
    timeout = spec[3]
    session = tests.create_session()
    if session ~= nil then
        local ok = false
        -- Here initfile installs the package manager and plugins, testfile runs the tests.
        tests.info("=> initialising test: " .. initfile)
        ok = runtest(initfile, { "nvim", "--headless", "-n", "-u", "test/" .. initfile, "-c", "quit" }, timeout)
        -- Only run tests if initialisation succeeded.
        if ok then
            tests.info("=> running test: " .. testfile)
            ok = runtest(testfile, { "nvim", "--headless", "-n", "-u", "test/" .. testfile }, timeout)
            if not ok then table.insert(failures, testfile) end
        else
            table.insert(failures, initfile)
        end
        tests.destroy_session() -- Destroy session outside the actual test file to ensure cleanup.
    else
        os.exit(1)
    end
end
local n_fails = vim.tbl_count(failures)
if n_fails > 0 then
    tests.info(string.format("FAILED: %d/%d\n", n_fails, #testspec))
    tests.info("\t" .. table.concat(failures, "\t"))
else
    tests.info("PASSED")
end
os.exit(n_fails)
