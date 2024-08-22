local uv = vim.uv
local command = vim.api.nvim_create_user_command
vim.opt.rtp:append(vim.fn.getcwd())

local function handle_signal(signal)
    -- Clean up child instances.
    if signal == "sigterm" then
        io.stdout:write("\nRunning sigterm handler\n")
        os.execute('pkill -TERM -P ' .. tostring(uv.os_getpid()))
    elseif signal == "sigint" then
        io.stdout:write("\nRunning sigint handler\n")
        -- Sending INT is not enough, children don't respond to it (kids these days...)
        os.execute('pkill -TERM -P ' .. tostring(uv.os_getpid()))
    end
    vim.cmd("qa!") -- Exit stage left.
end

local sigterm_handle = uv.new_signal()
uv.signal_start(sigterm_handle, "sigterm", handle_signal)
local sigint_handle = uv.new_signal()
uv.signal_start(sigint_handle, "sigint", handle_signal)

function TestInit()
    vim.opt.rtp:append('dep/mini.nvim')
    require('mini.test').setup({
        collect = {
            find_files = function()
                return vim.fn.globpath('test', '**/test_*.lua', true, true)
            end,
            -- silent = true,
        },
    })
    haunt = require('haunt').setup()
    vim.cmd.helptags('ALL')
    haunt._err_blocking = true
    io.stdout:write("Test suite setup completed for nvim instance with PID ", uv.os_getpid(), "\n")
end

if #vim.api.nvim_list_uis() == 0 then
    TestInit() -- Load test dependency automatically if headless.
else           -- Otherwise set up convenient user commands.
    command("TestInit", TestInit, { bar = true, desc = "Initialise testing context" })
    command("TestRun", [[=MiniTest.run()]], { desc = "Run test suite" })
end
