local Tests = {}
local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
vim.g.defer_time = 0

-- Tests.wait_ok = function() return vim.g.ok end
-- Tests.wait_got = function() return vim.g.got end

local function addtime(dt)
    vim.g.defer_time = vim.g.defer_time + dt
end

-- Check :h vim.system() for these.
Tests.INT = 2
Tests.TERM = 15
Tests.TERMCODE = 124

-- Send a message to neovim's error message buffer.
function Tests.err(msg) api.nvim_err_writeln(msg) end

-- Send a message to stderr and color it in red.
function Tests.crit(msg) io.stderr:write(string.format("\27[31m%s\27[m\n", msg)) end

-- Send a message to stdout and use boldface.
function Tests.info(msg) io.stdout:write(string.format("\27[1m%s\27[m\n", msg)) end

function Tests.load(plugin) -- Load either local or third-party plugin.
    local has_plugin, out = pcall(require, plugin)
    if has_plugin then
        return out
    else
        Tests.err(string.format("failed to load plugin '%s'", plugin))
        return nil
    end
end

-- Create test session in _testvar/.
function Tests.create_session()
    local ok = uv.fs_mkdir("_testvar", tonumber("755", 8))
    if not ok then
        -- Use io.stderr:write not Test.err, because this will be called in collect.lua!
        io.stderr:write("failed to create temporary directory '_testvar' for test session\n")
        return
    end
    local session = {
        root = "_testvar",
        module = "_testvar/fixtures.lua",
        lazydir = "_testvar/site/pack/lazy/opt/",
        lazylock = "_testvar/lazy-lock.json",
        pckr_path = "_testvar/site/pack/pckr/start/pckr.nvim",
        pckr_root = "_testvar/site/pack/",
    }
    local session_module = io.open(session.module, "w+")
    if session_module ~= nil then
        session_module:write("return {\n")
        for k, v in pairs(session) do
            session_module:write(string.format("%s = '%s',\n", k, v))
        end
        session_module:write("}\n")
    end
    io.close(session_module)
    return session
end

function Tests.destroy_session()
    -- Here 0 == FALSE, see :h Boolean.
    if fn.isdirectory("_testvar") ~= 0 then
        -- Here 0 == TRUE means the delete was successful.
        if fn.delete("_testvar", "rf") ~= 0 then
            -- Use io.stderr:write not Test.err, because this will be called in collect.lua!
            io.stderr:write("failed to remove '_testvar' directory\n")
        end
    end
end

function Tests.runtests(haunt)
    vim.g.ok = false
    vim.g.expected = nil
    vim.g.got = nil
    vim.opt.showmode = false
    Tests.help()
    -- Tests.always_fail()
    -- Tests.always_fail()
end

function Tests.check(expected, get_cb, pre_time, post_time)
    addtime(pre_time)
    vim.defer_fn(function()
        vim.g.expected = expected
        vim.g.got = get_cb()
    end, vim.g.defer_time)
    addtime(post_time)
    vim.defer_fn(function()
        if not (vim.g.got == vim.g.expected) then
            Tests.err(string.format("Expected: %s\nGot: %s\n", vim.g.expected, vim.g.got))
            vim.g.ok = false
        else
            vim.g.ok = true
        end
    end, vim.g.defer_time)
end

function Tests.typekeys(keys, special, mode)
    local _mode = mode or "t"
    if special then
        api.nvim_feedkeys(api.nvim_replace_termcodes(keys, true, false, true), _mode, false)
    else
        api.nvim_feedkeys(keys, _mode, false)
    end
end

function Tests.help()
    -- Check that :HauntHelp is working.
    Tests.typekeys("<Cmd>", true)
    Tests.typekeys("HauntHelp haunt\r")
    Tests.check("haunt.txt", function() return fn.fnamemodify(api.nvim_buf_get_name(0), ":t") end, 300, 50)

    -- Check that we can't open other buffers in the help window.
    Tests.typekeys("<Cmd>", true)
    Tests.typekeys("e README.md\r")
    Tests.check("haunt.txt", function() return fn.fnamemodify(api.nvim_buf_get_name(0), ":t") end, 300, 50)

    -- Check that we can go to a new help buffer with :help.
    Tests.typekeys("<Cmd>", true)
    Tests.typekeys("help help\r")
    Tests.check("helphelp.txt", function() return fn.fnamemodify(api.nvim_buf_get_name(0), ":t") end, 300, 50)

    -- Check that we can go to a new help buffer with :HauntHelp.
    Tests.typekeys("<Cmd>", true)
    Tests.typekeys("HauntHelp help\r")
    Tests.check("helphelp.txt", function() return fn.fnamemodify(api.nvim_buf_get_name(0), ":t") end, 300, 50)
end

function Tests.always_fail()
    local msg = "this test is expected to fail"
    Tests.check(msg, function() return vim.text.hexencode(msg) end, 0, 50)
end

return Tests
