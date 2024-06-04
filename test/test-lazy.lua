local opt = vim.opt
local tests = require("test.tests")
local session = require("_testvar.fixtures")
local lazydir = session.lazydir
local lazypath = lazydir .. "lazy.nvim"

opt.rtp:prepend(lazypath)
opt.pp:prepend(session.root .. "/site")
local lazy = tests.load("lazy")
if lazy ~= nil then
    vim.cmd.packadd { args = { "fzf" } }
    vim.cmd.packadd { args = { "quark.nvim" } }
    local quark = tests.load("quark")
    if quark ~= nil then
        quark.setup {
            fzf = { default_command = "rg --files --hidden --no-messages" }
        }
        tests.create_keybinds(quark)
        tests.runtests(quark)
    end
end
vim.defer_fn(function() os.exit(vim.g.ok) end, 3000)
