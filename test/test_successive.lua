local tc = require('test.context')
local child = tc.child
local fn = child.fn
local api = child.api
local input = child.type_keys
local sleep = vim.uv.sleep ---@diagnostic disable-line: undefined-field

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local eq = expect.equality
local neq = expect.no_equality

local T = new_set({ hooks = { pre_case = tc.setup, post_once = child.stop } })

local function buffile() return vim.fs.basename(fn.bufname()) end
local function haskey(t, key) return vim.tbl_contains(vim.tbl_keys(t), key) end

-- Floating {help|man}, three different tags in a row.
T['same-type-ijk'] = new_set({
    parametrize = {
        {
            {
                'haunt.help()',
                'haunt.help({ fargs = { ":HauntHelp" } })',
                'haunt.help({ fargs = { "help" } })'
            },
            { 'help.txt', 'haunt.txt', 'helphelp.txt' }
        },
        {
            {
                'haunt.man({ fargs = { "nvim" } })',
                'haunt.man({ fargs = { "man" } })',
                'haunt.man({ fargs = { "glibc" } })'
            },
            { "nvim(1)", "man(1)", "libc(7)" }
        },
    }
})
T['same-type-ijk']['multi'] = function(cmds, filenames)
    tc.lua(cmds[1])
    sleep(321)
    eq(buffile(), filenames[1])
    eq(fn.bufnr(), child.t.HauntState.buf)
    tc.lua(cmds[2])
    sleep(321)
    eq(buffile(), filenames[2])
    eq(fn.bufnr(), child.t.HauntState.buf)
    tc.lua(cmds[3])
    sleep(321)
    eq(buffile(), filenames[3])
    eq(fn.bufnr(), child.t.HauntState.buf)
end

-- Floating {help|man}, two different tags and closed in between.
T['same-type-i_j'] = new_set({
    parametrize = {
        {
            { 'haunt.help({ fargs = { ":HauntHelp" } })', 'haunt.help({ fargs = { "help" } })' },
            { 'haunt.txt',                                'helphelp.txt' }
        },
        {
            { 'haunt.man({ fargs = { "nvim" } })', 'haunt.man({ fargs = { "man" } })' },
            { "nvim(1)",                           "man(1)" }
        },
    }
})
T['same-type-i_j']['multi'] = function(cmds, filenames)
    tc.lua(cmds[1])
    sleep(321)
    eq(buffile(), filenames[1])
    eq(fn.bufnr(), child.t.HauntState.buf)
    input(":q<Cr>")
    neq(buffile(), filenames[1])
    tc.lua(cmds[2])
    sleep(321)
    eq(buffile(), filenames[2])
    eq(fn.bufnr(), child.t.HauntState.buf)
end

-- Floaing {help -> man|man -> help}, with and without closing in between.
T['man-help-ij'] = new_set({
    parametrize = {
        {
            'haunt.man({ fargs = { "nvim" } })',
            'haunt.help({ fargs = { ":HauntHelp" } })',
            "nvim(1)",
            "haunt.txt",
            false
        },
        {
            'haunt.man({ fargs = { "nvim" } })',
            'haunt.help({ fargs = { ":HauntHelp" } })',
            "nvim(1)",
            "haunt.txt",
            true
        },
        {
            'haunt.help({ fargs = { ":HauntHelp" } })',
            'haunt.man({ fargs = { "nvim" } })',
            "haunt.txt",
            "nvim(1)",
            false
        },
        {
            'haunt.help({ fargs = { ":HauntHelp" } })',
            'haunt.man({ fargs = { "nvim" } })',
            "haunt.txt",
            "nvim(1)",
            true
        },
    }
})
T['man-help-ij']['multi'] = function(s1, s2, name1, name2, close)
    tc.lua(s1)
    sleep(321)
    eq(buffile(), name1)
    if close then
        input(":q<Cr>")
        neq(buffile(), name1)
        sleep(123)
    end
    tc.lua(s2)
    sleep(321)
    eq(buffile(), name2)
end

-- Floating terminals, three different titles/jobs in a row.
T['term-ijk'] = function()
    local cmds = {
        'haunt.term()',
        'haunt.term({ fargs = { "ls" } })',
        'haunt.term({ fargs = { "-t", "foo" } })'
    }
    local titles = { vim.o.shell, "ls", "foo" }
    tc.lua(cmds[1])
    sleep(321)
    eq(haskey(child.t.HauntState.termbufs, titles[1]), true)
    eq(child.t.HauntState.termbufs[titles[1]], child.t.HauntState.buf)
    eq(fn.bufnr(), child.t.HauntState.buf)
    tc.lua(cmds[2])
    sleep(321)
    for _, v in pairs({titles[1], titles[2]}) do
        eq(haskey(child.t.HauntState.termbufs, v), true)
    end
    eq(child.t.HauntState.termbufs[titles[2]], child.t.HauntState.buf)
    eq(fn.bufnr(), child.t.HauntState.buf)
    tc.lua(cmds[3])
    sleep(321)
    for _, v in pairs(titles) do
        eq(haskey(child.t.HauntState.termbufs, v), true)
    end
    eq(child.t.HauntState.termbufs[titles[3]], child.t.HauntState.buf)
    eq(fn.bufnr(), child.t.HauntState.buf)
end

-- Floaing {term -> man|man -> term|term -> help|help -> term|term -> term},
-- with and without closing in between.
T['term-other-ij'] = new_set({
    parametrize = {
        {
            'haunt.term()',
            'haunt.man({ fargs = { "nvim" } })',
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], child.o.shell) end,
            function() eq(buffile(), "nvim(1)") end,
            false
        },
        {
            'haunt.term()',
            'haunt.man({ fargs = { "nvim" } })',
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], child.o.shell) end,
            function() eq(buffile(), "nvim(1)") end,
            true
        },
        {
            'haunt.man({ fargs = { "nvim" } })',
            'haunt.term({ fargs = { "ls" } })',
            function() eq(buffile(), "nvim(1)") end,
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], "ls") end,
            false
        },
        {
            'haunt.man({ fargs = { "nvim" } })',
            'haunt.term({ fargs = { "ls" } })',
            function() eq(buffile(), "nvim(1)") end,
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], "ls") end,
            true
        },
        {
            'haunt.term()',
            'haunt.help({ fargs = { ":HauntHelp" } })',
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], child.o.shell) end,
            function() eq(buffile(), "haunt.txt") end,
            false
        },
        {
            'haunt.term()',
            'haunt.help({ fargs = { ":HauntHelp" } })',
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], child.o.shell) end,
            function() eq(buffile(), "haunt.txt") end,
            true
        },
        {
            'haunt.help({ fargs = { ":HauntHelp" } })',
            'haunt.term({ fargs = { "-t", "foo" } })',
            function() eq(buffile(), "haunt.txt") end,
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], "foo") end,
            false
        },
        {
            'haunt.help({ fargs = { ":HauntHelp" } })',
            'haunt.term({ fargs = { "-t", "foo" } })',
            function() eq(buffile(), "haunt.txt") end,
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], "foo") end,
            true
        },
        {
            'haunt.term({ fargs = { "ls" } })',
            'haunt.term({ fargs = { "-t", "foo" } })',
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[1], "ls") end,
            function() eq(vim.tbl_keys(child.t.HauntState.termbufs)[2], "foo") end,
            true
        },
    }
})
T['term-other-ij']['multi'] = function(s1, s2, f1, f2, close)
    tc.lua(s1)
    sleep(321)
    f1()
    if close then
        input(":q<Cr>")
        eq(api.nvim_win_is_valid(child.t.HauntState.win), false)
        sleep(123)
    end
    tc.lua(s2)
    sleep(321)
    f2()
end

return T
