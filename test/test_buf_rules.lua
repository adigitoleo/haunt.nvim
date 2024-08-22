local tc = require('test.context')
local child = tc.child
local sleep = vim.uv.sleep

local new_set = MiniTest.new_set
local expect = MiniTest.expect
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

return T
