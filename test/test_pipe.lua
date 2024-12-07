local tc = require('test.context')
local child = tc.child
local fn = child.fn
local input = child.type_keys
local sleep = vim.uv.sleep

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local eq = expect.equality
local neq = expect.no_equality
local err = expect.error
local ok = expect.no_error

local T = new_set({ hooks = { pre_case = tc.setup, post_once = child.stop } })

T['send-whole'] = new_set {
    parametrize = {
        -- Test fenced python code block embedded in a markdown buffer.
        { "markdown", "python", { "# H1", "", "Text, not code", "", "### H3", "", "```", "x = 1", "y = 2", "print(x + y)", "```" } },
        -- Test lua code.
        { "lua",      "lua",    { "function foo()", "local x = 1", "local y = 2", "print(x + y)", "end", "foo()" } }
    }
}
T['send-whole']['multi'] = function(ft, exe, lines)
    tc.setopt("filetype", ft)
    tc.put(lines)
    sleep(123) -- Wait for lines to fill buffer.
    input('10j')
    local id = tc.lua_get('haunt.term({ fargs = { "' .. exe .. '" } })')
    sleep(3210) -- Wait for floating terminal to open.
    tc.cmd('stopinsert')
    tc.cmd('quit')
    sleep(123)                         -- Wait for floating terminal to close.
    tc.lua('haunt.send(' .. id .. ')') -- Send fenced code block at cursor (markdown only) or whole buffer, by default.
    sleep(123)                         -- Wait for data transfer to terminal job stdin.
    tc.lua('haunt.term({ fargs = { "' .. exe .. '" } })')
    sleep(321)                         -- Wait for floating terminal to open.
    tc.cmd('stopinsert')
    -- Check last non-empty line (empty lines may include interpreter prompts).
    eq(vim.iter(vim.tbl_filter(function(str) return str ~= "" and str ~= ">>> " and str ~= "> " end, tc.get())):last(), '3')
end

return T
