local tc = require('test.context')
local child = tc.child
local sleep = vim.uv.sleep

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local eq = expect.equality
local err = expect.error

local T = new_set({ hooks = { pre_case = tc.setup, post_once = child.stop } })

T['sticky-buffers'] = new_set({
    parametrize = {
        { 'haunt.help()' }, { 'haunt.man({ fargs = { "nvim(1)" }})' }, { 'haunt.term()' }
    }
})
T['sticky-buffers']['multi'] = function(s)
    tc.lua(s)
    sleep(321)
    err(function() tc.cmd("b#") end, "Cannot switch buffer")
end

T['term-startinsert'] = new_set({
    parametrize = {
        { { 'haunt.term()' },                                  { 1 } },
        { { 'haunt.term()', 'haunt.reset()', 'haunt.term()' }, { 1, 3 } },
        { { 'haunt.help()', 'haunt.reset()', 'haunt.term()' }, { 3 } }
    }
})
T['term-startinsert']['multi'] = function(cmds, indexes)
    for i, cmd in pairs(cmds) do
        tc.lua(cmd)
        sleep(321)
        if vim.list_contains(indexes, i) then
            eq(child.fn.mode(), 't')
        end
    end
end

return T
