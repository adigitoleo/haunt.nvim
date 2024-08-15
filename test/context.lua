local Context = {}
local child = MiniTest.new_child_neovim()

-- Hooks.

Context.setup = function() child.restart({ '-u', 'test/init.lua' }) end

-- Utilities.

function Context.rethrow_errmsg()
    local errmsg = child.v.errmsg
    if errmsg ~= nil and #errmsg > 0 then error(errmsg) end
end

function Context.rethrow_messages()
    local messages = vim.fn.split(child.fn.execute('messages'), "\n")
    if messages ~= nil and #messages > 0 then error(vim.fn.join(messages, "\n")) end
end

function Context.put(lines)
    return child.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

function Context.get()
    return child.api.nvim_buf_get_lines(0, 0, -1, true)
end

function Context.setopt(name)
    return child.api.nvim_set_option_value(name, { scope = "local" })
end

function Context.getopt(name)
    return child.api.nvim_get_option_value(name, { scope = "local" })
end

function Context.cmd(str) return child.cmd(str) end

function Context.lua(str) return child.lua(str) end

function Context.lua_get(str) return child.lua_get(str) end

Context.child = child
return Context
