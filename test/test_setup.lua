local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

T['default'] = function()
    local h = haunt.setup {}
    expect.equality(h.config, {
        define_commands = true,
        window = {
            width_frac = 0.8,
            height_frac = 0.8,
            winblend = 30,
            border = "single",
            show_title = true,
            title_pos = "left",
            zindex = 11,
        }
    })
end
T['all-valid'] = function()
    expect.no_error(haunt.setup, {
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

local _c = haunt.config
T['invalid-define_commands'] = function()
    expect.error(function()
        haunt.setup { define_commands = "foo" }
    end, "must be a " .. type(_c.define_commands))
end
T['invalid-option'] = function()
    expect.error(function()
        haunt.setup { option = "foo" }
    end, "unrecognized config option")
end
T['invalid-section'] = function()
    expect.error(function()
        haunt.setup { section = { option = "foo" } }
    end, "unrecognized config option")
end
T['invalid-window-option'] = function()
    expect.error(function()
        haunt.setup { window = { option = "foo" } }
    end, "unrecognized config option")
end
T['invalid-window.width_frac'] = function()
    expect.error(function()
        haunt.setup { window = { width_frac = "foo" } }
    end, "must be a " .. type(_c.window.width_frac))
end
T['invalid-window.height_frac'] = function()
    expect.error(function()
        haunt.setup { window = { height_frac = "foo" } }
    end, "must be a " .. type(_c.window.height_frac))
end
T['invalid-window.winblend'] = function()
    expect.error(function()
        haunt.setup { window = { winblend = "foo" } }
    end, "must be a " .. type(_c.window.winblend))
end
T['invalid-window.border'] = function()
    expect.error(function()
        haunt.setup { window = { border = 42 } }
    end, "must be a " .. type(_c.window.border))
end
T['invalid-window.show_title'] = function()
    expect.error(function()
        haunt.setup { window = { show_title = "foo" } }
    end, "must be a " .. type(_c.window.show_title))
end
T['invalid-window.title_pos'] = function()
    expect.error(function()
        haunt.setup { window = { title_pos = 42 } }
    end, "must be one of")
end
T['invalid-window.title_pos-string'] = function()
    expect.error(function()
        haunt.setup { window = { title_pos = "foo" } }
    end, "must be one of")
end
T['invalid-window.zindex'] = function()
    expect.error(function()
        haunt.setup { window = { zindex = "foo" } }
    end, "must be a " .. type(_c.window.zindex))
end

return T
