local tc = require('test.context')
local child = tc.child
local input = child.type_keys
local sleep = vim.uv.sleep

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local eq = expect.equality
local err = expect.error
local ok = expect.no_error

local T = new_set({ hooks = { pre_case = tc.setup, post_once = child.stop } })

local defaults = haunt.config -- get default config from parent session

T['default'] = function()
    tc.lua('haunt = haunt.setup {}')
    eq(tc.lua_get('haunt.config'), defaults)
end
T['all-valid'] = function()
    ok(haunt.setup, {
        define_commands = false,
        window = {
            width_frac = 0.7,
            height_frac = 0.7,
            winblend = 33,
            border = "double",
            show_title = false,
            title_pos = "right",
            zindex = 12,
        }
    })
end

T['unrecognized'] = new_set({
    parametrize = {
        { 'foo = false' },                 -- unrecognized option
        { 'foo = { border = "double" }' }, -- unrecognized section
        { 'window = { foo = "double" }' }, -- valid section but unrecognized option
    }
})
T['unrecognized']['multi'] = function(s)
    err(function() tc.lua('haunt.setup { ' .. s .. ' }') end, "unrecognized config option")
end

T['invalid'] = new_set({
    parametrize = {
        { 'define_commands = "foo"',         type(defaults.define_commands) },
        { 'quit_help_with_q = "foo"',        type(defaults.quit_help_with_q) },
        { 'window = { width_frac = "foo" }', type(defaults.window.width_frac) },
        { 'window = {height_frac = "foo"}',  type(defaults.window.height_frac) },
        { 'window = {winblend = "foo"}',     type(defaults.window.winblend) },
        { 'window = {border = 42}',          type(defaults.window.border) },
        { 'window = {show_title = "foo"}',   type(defaults.window.show_title) },
        { 'window = {zindex = "foo"}',       type(defaults.window.zindex) },
    }
})
T['invalid']['multi'] = function(s, t)
    err(function() tc.lua('haunt.setup { ' .. s .. ' }') end, "must be a " .. t)
end

T['invalid-title_pos'] = new_set({ parametrize = { { 42, "foo" } } })
T['invalid-title_pos']['multi'] = function(x)
    err(
        function() tc.lua('haunt.setup { window = { title_pos = ' .. x .. ' } }') end,
        "must be one of"
    )
end

T['no-commands'] = function()
    tc.lua('haunt = haunt.setup { define_commands = false }')
    err(function() tc.cmd("HauntHelp") end, "Not an editor command")
    sleep(123)
    err(function() tc.cmd("HauntMan") end, "Not an editor command")
    sleep(123)
    err(function() tc.cmd("HauntTerm") end, "Not an editor command")
    sleep(123)
    err(function() tc.cmd("HauntLs") end, "Not an editor command")
    sleep(123)
    err(function() tc.cmd("HauntReset") end, "Not an editor command")
end

T['quit-help-with-q'] = function()
    tc.lua('haunt = haunt.setup { quit_help_with_q = false }')
    tc.cmd('HauntHelp')
    sleep(321)
    input("q<Cr>") -- Trailing <Cr> needed to avoid blocking for macro recording (default q mapping)
    sleep(321)
    eq(tc.getopt("buftype"), "help")
    eq(tc.getopt("filetype"), "help")
end

return T
