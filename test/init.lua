local command = vim.api.nvim_create_user_command
vim.opt.rtp:append(vim.fn.getcwd())

local function handle_sigterm()
    -- Propagate TERM signal to child instances.
    vim.print("Running sigterm handler")
    os.execute('pkill -TERM -P ' .. tostring(vim.uv.os_getpid()))
    -- Exit stage left.
    vim.cmd("qa!")
end

local sigterm_handle = vim.uv.new_signal()
vim.uv.signal_start(sigterm_handle, "sigterm", handle_sigterm)

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
end

command("TestInit", TestInit, { bar = true, desc = "Initialise testing context" })
command("TestRun", [[=MiniTest.run()]], { desc = "Run test suite" })

-- Load test dependency automatically if headless.
if #vim.api.nvim_list_uis() == 0 then
    TestInit()
end
