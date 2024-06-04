local opt = vim.opt
local tests = require("test.tests")
local session = require("_testvar.fixtures")
local pckr_path = session.pckr_path

opt.rtp:prepend(pckr_path)
opt.pp:prepend(session.root .. "/site")
local pckr = tests.load("pckr")
if pckr ~= nil then
    vim.cmd.packadd { args = { "haunt.nvim" } }
    vim.cmd.helptags { args = { "ALL" } }
    local haunt = tests.load("haunt")
    if haunt ~= nil then tests.runtests(haunt) end
end
vim.defer_fn(function() os.exit(vim.g.ok) end, vim.g.defer_time + 1000)
