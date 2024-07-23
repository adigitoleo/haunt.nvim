local Common = {}
local child = MiniTest.new_child_neovim()

Common.setup = function()
    child.restart({ '-u', 'test/init.lua' })
end

Common.teardown = function()
    -- Required because somehow vim.t assignments always evaluate on the parent nvim process.
    -- This leads to vim.t state being carried over between tests even after child.restart().
    vim.t.HauntState = nil
end

Common.child = child
return Common
