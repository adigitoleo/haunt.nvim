local opt = vim.opt
local fn = vim.fn
local tests = require("test.tests")
local session = require("_testvar.fixtures")
local lazydir = session.lazydir
local lockpath = session.lazylock

local function pkgbootstrap()
    local lazypath = lazydir .. "lazy.nvim"
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
        fn.system {
            "git",
            "clone",
            "--filter=blob:none",
            "https://github.com/folke/lazy.nvim.git",
            "--branch=stable", -- latest stable release
            lazypath,
        }
    end
    opt.rtp:prepend(lazypath)
end

pkgbootstrap()
local lazy = tests.load("lazy")
if lazy ~= nil then
    lazy.setup(
        {
            -- This shouldn't be needed on most Linux systems if the fzf package is installed.
            { url = "https://github.com/junegunn/fzf", build = ":call fzf#install()" },
            {
                url = "https://git.sr.ht/~adigitoleo/quark.nvim",
                branch = "dev",
                config = function()
                    local quark = tests.load("quark")
                    if quark then
                        quark.setup {
                            fzf = { default_command = "rg --files --hidden --no-messages" }
                        }
                        tests.create_keybinds(quark)
                    end
                end
            }
        },
        {
            root = lazydir,
            lockfile = lockpath,
            performance = { cache = { enabed = false } },
        }
    )
end
