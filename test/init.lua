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

-- Load test dependency automatically if headless.
if #vim.api.nvim_list_uis() == 0 then
    TestInit()
end
