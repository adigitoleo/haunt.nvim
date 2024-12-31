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
local mock_md = { "# H1", "", "Text, not code", "", "### H3", "", "```", "x = 1", "y = 2", "print(x + y)", "```" }

local function match_empty_lines(str) return str ~= "" and str ~= ">>> " and str ~= "> " end

T['send-whole'] = new_set {
    parametrize = {
        -- Test fenced python code block embedded in a markdown buffer.
        { "markdown", "python", mock_md },
        -- Test lua code.
        { "lua",      "lua",    { "function foo()", "local x = 1", "local y = 2", "print(x + y)", "end", "foo()" } }
    }
}
T['send-whole']['multi'] = function(ft, exe, lines)
    tc.setopt("filetype", ft)
    tc.put(lines)
    sleep(123)  -- Wait for lines to fill buffer.
    local id = tc.lua_get('haunt.term({ fargs = { "' .. exe .. '" } })')
    sleep(3210) -- Wait for floating terminal to open.
    tc.cmd('stopinsert')
    tc.cmd('quit')
    sleep(123)                         -- Wait for floating terminal to close.
    input('10j')
    tc.lua('haunt.send(' .. id .. ')') -- Send fenced code block at cursor (markdown only) or whole buffer, by default.
    sleep(123)                         -- Wait for data transfer to terminal job stdin.
    tc.lua('haunt.term({ fargs = { "' .. exe .. '" } })')
    sleep(321)                         -- Wait for floating terminal to open.
    tc.cmd('stopinsert')
    -- Check last non-empty line (empty lines may include interpreter prompts).
    eq(vim.iter(vim.tbl_filter(match_empty_lines, tc.get())):last(), '3')
end

T['send-whole-md-err'] = function()
    tc.setopt("filetype", "markdown")
    tc.put(mock_md)
    sleep(123)  -- Wait for lines to fill buffer.
    local id = tc.lua_get('haunt.term({ fargs = { "python" } })')
    sleep(3210) -- Wait for floating terminal to open.
    tc.cmd('stopinsert')
    tc.cmd('quit')
    sleep(123) -- Wait for floating terminal to close
    input('3j')
    err(function() tc.lua('haunt.send(' .. id .. ')') end, "cursor is not in a code block")
end

T['send-lines'] = new_set {
    parametrize = {
        { "python", "python", 'ggV2j', { "x = 1", "y = 2", "print(x + y)", "print('Should not be printed')" } },
        { "lua",    "lua",    'ggV5j', { "function foo()", "local x = 1", "local y = 2", "print(x + y)", "end", "foo()", "print('Should not be printed')" } }
    }
}
T['send-lines']['multi'] = function(ft, exe, keys, lines)
    tc.setopt("filetype", ft)
    tc.put(lines)
    sleep(123)  -- Wait for lines to fill buffer.
    local id = tc.lua_get('haunt.term({ fargs = { "' .. exe .. '" } })')
    sleep(3210) -- Wait for floating terminal to open.
    tc.cmd('stopinsert')
    tc.cmd('quit')
    sleep(123)                         -- Wait for floating terminal to close.
    input(keys)
    tc.lua('haunt.send(' .. id .. ')') -- Send selected lines.
    sleep(123)                         -- Wait for data transfer to terminal job stdin.
    tc.lua('haunt.term({ fargs = { "' .. exe .. '" } })')
    sleep(321)                         -- Wait for floating terminal to open again.
    tc.cmd('stopinsert')
    -- Check last non-empty line (empty lines may include interpreter prompts).
    eq(vim.iter(vim.tbl_filter(match_empty_lines, tc.get())):last(), '3')
end

return T
