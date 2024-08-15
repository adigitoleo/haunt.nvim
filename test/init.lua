local command = vim.api.nvim_create_user_command
vim.opt.rtp:append(vim.fn.getcwd())

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
    haunt = require('haunt')
    vim.cmd.helptags('ALL')
    haunt._err_blocking = true
end

command("TestInit", TestInit, { desc = "Initialise testing context" })
command("TestRun", [[=MiniTest.run()]], { desc = "Run test suite" })

-- Load test dependency automatically if headless.
if #vim.api.nvim_list_uis() == 0 then
    TestInit()
end
