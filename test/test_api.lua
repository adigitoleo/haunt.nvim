local tc = require('test.context')
local child = tc.child
local fn = child.fn
local input = child.type_keys
local sleep = vim.uv.sleep ---@diagnostic disable-line: undefined-field

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local eq = expect.equality
local neq = expect.no_equality
local err = expect.error
local ok = expect.no_error

local T = new_set({ hooks = { pre_case = tc.setup, post_once = child.stop } })

local function buffile() return vim.fs.basename(fn.bufname()) end

T['help-api'] = new_set({
    parametrize = {
        { -- Should open :help
            function() tc.lua('haunt.help()') end,
            "help.txt"
        },
        { -- Should open :help <cword>
            function()
                tc.put { "help" }; input("gg"); tc.lua('haunt.help()')
            end,
            "helphelp.txt"
        },
        { -- Should open :help haunt
            function() tc.lua('haunt.help({ fargs = { "haunt" } })') end,
            "haunt.txt"
        }
    }
})
T['help-api']['multi'] = function(f, filename)
    f()
    sleep(321)
    neq(child.t.HauntState.buf, -1)
    neq(child.t.HauntState.win, -1)
    eq(tc.getopt("buftype"), "help")
    eq(tc.getopt("filetype"), "help")
    eq(buffile(), filename)
end

T['help-api-invalid'] = function()
    tc.put { "0245240582304952304952309526" }
    input("gg")
    err(function()
        tc.lua('haunt.help()')
        tc.rethrow_messages()
    end, "E149: Sorry, no help for 0245240582304952304952309526")
    sleep(321)
end

-- Should open :terminal
T['term-api-nargs0'] = function()
    tc.lua('haunt.term()')
    sleep(321)
    neq(child.t.HauntState.buf, -1)
    neq(child.t.HauntState.win, -1)
    eq(#vim.tbl_keys(child.t.HauntState.termbufs), 1)
    eq(tc.getopt("buftype"), "terminal")
    neq(child.b.term_title, nil)
end

T['term-api'] = new_set({
    parametrize = {
        { -- Should open terminal named foo
            '{ "-t", "foo" }', "foo"
        },
        { -- Should open terminal named ls running !ls
            '{ "ls" }', "ls"
        },
        { -- Should open terminal named "title_not_cmd"  running !ls
            '{ "-t", "title_not_cmd", "ls" }', "title_not_cmd"
        }
    }
})
T['term-api']['multi'] = function(fargs, title)
    tc.lua('haunt.term({fargs = ' .. fargs .. '})')
    sleep(321)
    neq(child.t.HauntState.buf, -1)
    neq(child.t.HauntState.win, -1)
    eq(tc.getopt("buftype"), "terminal")
    neq(child.b.term_title, nil)
    eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], title)
end

T['man-api-nargs0'] = function() -- Can't run :Man without an argument
    err(function() tc.lua('haunt.man()') end, ":Man requires an argument")
end

-- Check both valid and invalid :Man <cword>
T['man-api-cword'] = new_set({ parametrize = { { "nvim", ok }, { "foo", err } } })
T['man-api-cword']['multi'] = function(cword, f)
    tc.put { cword }
    input("gg")
    f(function()
        tc.lua('haunt.man()')
        sleep(321)
        tc.rethrow_messages()
    end)
end

-- Should open :Man nvim
T['man-api-nargs1'] = function()
    tc.lua('haunt.man({ fargs = { "nvim" } })')
    sleep(321)
    neq(child.t.HauntState.buf, -1)
    neq(child.t.HauntState.win, -1)
    eq(tc.getopt("filetype"), "man")
end

-- Can't open :Man foo
T['man-api-nargs1-bad'] = function()
    err(function() tc.lua('haunt.man({ fargs = { "foo" } })') end, "no manual entry for foo")
end

-- These call vim.print and so must be wrapped with :silent (errors will still propagate)
T['ls-api'] = function() tc.cmd [[silent lua haunt.ls()]] end
T['ls-api-bang'] = function() tc.cmd [[silent lua haunt.ls({ bang = true })]] end

return T
