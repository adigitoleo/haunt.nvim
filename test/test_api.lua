local common = require('test.common')
local new_set = MiniTest.new_set
local expect = MiniTest.expect
local api = vim.api

local T = new_set({
    hooks = {
        pre_case = common.setup,
        post_case = common.teardown,
        post_once = common.child.stop,
    }
})

-- Should open :help
T['help-api'] = function() haunt.help() end
-- Should open :help <cword>
T['help-api-cword'] = function()
    vim.schedule(function() api.nvim_buf_set_text(0, 0, 0, 0, 0, { "haunt" }) end)
    vim.schedule(function() common.child.type_keys("gg") end)
    vim.schedule(function() haunt.help() end)
end
-- Should open :help haunt
T['help-api-arg'] = function() haunt.help({ fargs = { "haunt" } }) end

-- Should open :terminal
T['term-api'] = function() haunt.term() end
-- Should open a terminal named foo
T['term-api-title'] = function() haunt.term({ fargs = { "-t", "foo" } }) end
-- Should run !ls in a terminal
T['term-api-cmd'] = function() haunt.term({ fargs = { "ls" } }) end
-- Should run !ls in a terminal named 'title_not_cmd'
T['term-api-title-cmd'] = function() haunt.term({ fargs = { "-t", "title_not_cmd", "ls" } }) end

-- Can't run :Man without an argument
T['man-api'] = function() expect.error(haunt.man, ":Man requires an argument") end
-- Should open :Man <cword>
T['man-api-cword'] = function()
    vim.schedule(function() api.nvim_buf_set_text(0, 0, 0, 0, 0, { "nvim" }) end)
    vim.schedule(function() common.child.type_keys("gg") end)
    vim.schedule(function() haunt.man() end)
end
-- Can't open :Man <cword> for invalid <cword>
T['man-api-cword-invalid'] = function()
    vim.schedule(function() api.nvim_buf_set_text(0, 0, 0, 0, 0, { "foo" }) end)
    vim.schedule(function() common.child.type_keys("gg") end)
    vim.schedule(function() expect.error(function() haunt.man() end) end)
end
-- Should open :Man nvim
T['man-api-arg'] = function() haunt.man({ fargs = { "nvim" } }) end
-- Can't open :Man foo
T['man-api-arg-invalid'] = function() expect.error(haunt.man({ fargs = { "foo" } })) end

-- These call vim.print and so must be wrapped with :silent (errors will still propagate)
T['ls-api'] = function() vim.cmd [[silent lua haunt.ls()]] end
T['ls-api-arg'] = function() vim.cmd [[silent lua haunt.ls({ bang = true })]] end

return T
