local fn = vim.fn
local opt = vim.opt
local tests = require("test.tests")
local session = require("_testvar.fixtures")
local package_root = session.pckr_root
local pckr_path = session.pckr_path

local function pkgbootstrap()
    if not (vim.uv or vim.loop).fs_stat(pckr_path) then
        -- pckr.nvim is less mature than lazy.nvim so we use git HEAD rather than a stable branch/tag.
        fn.system { "git", "clone", "--depth", "1", "https://github.com/lewis6991/pckr.nvim", pckr_path }
    end
    opt.rtp:prepend(pckr_path)
end
pkgbootstrap()

local pckr = tests.load("pckr")
if pckr ~= nil then
    pckr.setup {
        package_root = package_root,
        display = { non_interactive = true },
    }
    pckr.add {
        {
            "https://git.sr.ht/~adigitoleo/haunt.nvim",
            branch = "dev",
        }
    }
end
