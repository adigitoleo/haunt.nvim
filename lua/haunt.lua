local api = vim.api
local fn = vim.fn
local command = api.nvim_create_user_command
local Haunt = {}

Haunt.config = {
    define_commands = true, -- toggle to prevent definition of default user commands
    window = {
        width_frac = 0.8,   -- width of floating window as a fraction of total width
        height_frac = 0.8,  -- height of floating window as a fraction of total height
        winblend = 30,      -- transparency setting
        border = "single",  -- border style, see :h floatwin-api
        show_title = true,  -- show a title in the floating window border?
        title_pos = "left", -- position for the border title, see :h api-floatwin
        zindex = 11,        -- floating window 'priority'
    },
}

Haunt.state = {    -- Local to a tabpage
    buf = -1,      -- ID of the buffer currently displayed in the floating window
    win = -1,      -- ID of the floating window
    title = "",    -- Most recent title of the floating window
    termbufs = {}, -- maps known terminal 'titles' to their buffer IDs
}

-- Use error(), which is blocking, instead of nvim_err_writeln(), which is not.
-- This is used in the test suite and could be useful for debugging.
Haunt._err_blocking = false

local function is_executable(cmd) if fn.executable(cmd) > 0 then return true else return false end end
local function warn(msg)
    local erf = api.nvim_err_writeln
    if Haunt._err_blocking then erf = error end
    erf("[haunt.nvim]: " .. msg)
end

local function load(plugin) -- Load either local or third-party plugin.
    local has_plugin, out = pcall(require, plugin)
    if has_plugin then
        return out
    else
        warn("failed to load plugin '" .. plugin .. "'")
        return nil
    end
end

-- Validate custom user config, fall back to defaults defined above.
local function validate(key, value, section)
    local schema = Haunt.config
    local got_type = type(value)
    local option = key .. " = " .. tostring(value)
    if section then
        option = table.concat({ section, key }, ".") .. " = " .. tostring(value)
        if schema[section] == nil or schema[section][key] == nil then
            warn("unrecognized config option " .. option)
            return nil
        elseif section == "window" then
            if (key == "width_frac" or key == "height_frac" or key == "winblend" or key == "zindex") and got_type ~= "number" then
                warn(option .. " must be a number")
                return schema[section][key]
            elseif key == "show_title" and got_type ~= "boolean" then
                warn(option .. " must be a boolean")
                return schema[section][key]
            elseif key == "title_pos" and not (value == "left" or value == "right" or value == "center" or value == nil) then
                warn(option .. " must be one of: 'left', 'right', 'center' or nil")
                return schema[section][key]
            elseif key == "border" and not (got_type == "string" or got_type == "table") then
                warn(option .. " must be a string or array")
                return schema[section][key]
            end
        end
    elseif schema[key] == nil then
        warn("unrecognized config option " .. option)
        return nil
    elseif key == "define_commands" and got_type ~= "boolean" then
        warn(option .. " must be a boolean")
        return schema[key]
    end
    return value
end

-- Setup function to allow and validate user configuration.
function Haunt.setup(config)
    for k, v in pairs(config) do
        if type(v) == "table" then
            for _k, _v in pairs(v) do
                Haunt.config[k][_k] = validate(_k, _v, k)
            end
        else
            Haunt.config[k] = validate(k, v)
        end
    end
    return Haunt
end

-- (Re)draw the floating window.
local function draw(win, buf, title)
    local wc = vim.o.columns
    local wl = vim.o.lines
    local width = math.ceil(wc * Haunt.config.window.width_frac)
    local height = math.ceil(wl * Haunt.config.window.height_frac - 4)
    local config = {
        border = Haunt.config.window.border,
        relative = "editor",
        style = "minimal",
        width = width,
        height = height,
        col = math.ceil((wc - width) * 0.5),
        row = math.ceil((wl - height) * 0.5 - 1),
        zindex = Haunt.config.window.zindex,
    }
    if title ~= nil then
        config.title = Haunt.config.window.show_title and "[" .. title .. "]" or nil
        config.title_pos = Haunt.config.window.title_pos
    end
    if api.nvim_buf_is_valid(vim.t.HauntState.buf) and api.nvim_win_is_valid(vim.t.HauntState.win) then
        api.nvim_win_set_config(win, config)
    else
        win = api.nvim_open_win(buf, true, config)
    end
    api.nvim_set_option_value("winblend", Haunt.config.window.winblend, { win = win })
    return win
end

-- Open or focus floating window and set {buf|file}type.
local function floating(buf, win, bt, ft, title)
    -- buf: possibly existing buffer
    -- win: possibly existing window
    -- bt: desired buftype
    -- ft: desired filetype
    -- title: title to be displayed in the window border
    if not api.nvim_buf_is_valid(buf) then
        buf = api.nvim_create_buf(true, false)
    end
    if bt ~= "terminal" then -- Ignore bt = "terminal" which is not allowed.
        api.nvim_set_option_value("buftype", bt, { buf = buf })
        api.nvim_set_option_value("filetype", ft, { buf = buf })
    end
    win = draw(win, buf, title)
    api.nvim_set_current_win(win)
    api.nvim_set_current_buf(buf)
    return buf, win
end

-- Don't allow switching buffers of the floating window except via our API.
local function lock_to_win(buf, win)
    api.nvim_create_autocmd({ "BufWinLeave" },
        {
            buffer = buf,
            callback = vim.schedule_wrap(function(ev)
                if api.nvim_win_is_valid(win) then api.nvim_set_current_buf(ev.buf) end
                if vim.o.buftype == "help" then
                    -- Set ft=help again to redraw conceal formatting.
                    api.nvim_set_option_value("filetype", "help", { buf = ev.buf })
                    -- Restore transparency.
                    api.nvim_set_option_value("winblend", Haunt.config.window.winblend, { win = win })
                end
            end)
        })
    api.nvim_create_autocmd({ "VimResized" },
        {
            buffer = buf,
            callback = vim.schedule_wrap(function(ev)
                if api.nvim_win_is_valid(vim.t.HauntState.win) and api.nvim_buf_is_valid(ev.buf) then
                    draw(vim.t.HauntState.win, ev.buf)
                end
            end)
        })
end

local function get_state()
    local state = {}
    if vim.t.HauntState == nil then
        state = vim.deepcopy(Haunt.state)
        vim.t.HauntState = state
    else
        state = vim.tbl_deep_extend("force", state, vim.t.HauntState)
    end
    return state
end

local function set_state(state)
    vim.t.HauntState = state
    if api.nvim_buf_is_valid(vim.t.HauntState.buf) and api.nvim_win_is_valid(vim.t.HauntState.win) then
        lock_to_win(vim.t.HauntState.buf, vim.t.HauntState.win)
    end
end

local function termfail(msg, state)
    warn(msg)
    set_state(state)
end

local function is_terminal_buf(maybe_buf_number)
    return pcall(function() api.nvim_buf_get_var(maybe_buf_number, "term_title") end)
end

function Haunt.term(opts)
    local state = get_state()
    local title = nil
    local cmd = { vim.o.shell }
    local termbuf = -1
    if (opts and opts.fargs[1] == "-t") then -- Pick up explicit titles set with -t <title>.
        table.remove(opts.fargs, 1)
        title = opts.fargs[1]
        if title ~= nil then
            table.remove(opts.fargs, 1)
        else
            termfail("missing argument for -t", state)
            return
        end
    end
    if (opts and vim.tbl_count(opts.fargs) > 0) then cmd = opts.fargs end
    local maybe_buf_number = tonumber(cmd[1], 10) -- Allow opening existing terminal buffers by buffer number.
    if is_executable(cmd[1]) then
        if title == nil then title = cmd[1] end   -- Use the first arg (executable name) as the title by defualt.
    elseif maybe_buf_number ~= nil then
        if title == nil then
            termfail(
                "viewing an existing terminal buffer in the floating window requires setting a title with -t <title>",
                state)
            return
        elseif is_terminal_buf(maybe_buf_number) then
            termbuf = tonumber(cmd[1], 10)
            if state.termbufs[title] == nil then
                state.termbufs[title] = termbuf
            else
                termfail("title is already in use: " .. title, state)
                return
            end
        else
            termfail(maybe_buf_number .. " is not a valid terminal buffer number", state)
            return
        end
    else
        termfail(cmd[1] .. " is not executable", state)
        return
    end
    local create_new = false
    if is_terminal_buf(state.termbufs[title]) then
        termbuf = state.termbufs[title]
    else
        create_new = true
    end
    termbuf, state.win = floating(termbuf, state.win, "terminal", "", title)
    local job_id = nil
    if create_new then
        job_id = fn.termopen(cmd, {
            on_exit = function()
                if vim.t.HauntState ~= nil then
                    local _state = vim.t.HauntState
                    _state.termbufs[title] = nil
                    vim.t.HauntState = _state
                end
                if cmd[1] == vim.o.shell then
                    api.nvim_input("<Cr>")
                end
            end
        })
        state.termbufs[title] = termbuf
    end
    state.buf = termbuf
    state.title = title
    set_state(state)
    return job_id
end

function Haunt.ls(opts)
    local terminals = {}
    if (opts and opts.bang) then
        vim.tbl_map(function(v) terminals[api.nvim_buf_get_var(v, "term_title")] = v end,
            vim.tbl_filter(
                function(v)
                    if fn.getbufvar(v, "&buftype") == "terminal" then return v end
                    return false
                end, api.nvim_list_bufs()
            )
        )
    elseif vim.t.HauntState ~= nil then
        for k, v in pairs(vim.t.HauntState.termbufs) do
            if api.nvim_buf_is_valid(v) then
                terminals[k] = v
            end
        end
        vim.t.HauntState.termbufs = terminals -- Take the opportunity to clean up dead buffer refs.
    end
    vim.print(vim.inspect(terminals))
end

function Haunt.help(opts)
    local state = get_state()
    local arg = fn.expand("<cword>")
    if (opts and vim.tbl_count(opts.fargs) > 0) then arg = opts.fargs[1] end
    state.buf, state.win = floating(state.buf, state.win, "help", "help", "help")
    lock_to_win(state.buf, state.win)
    local cmdparts = {}
    cmdparts = vim.tbl_extend("keep", cmdparts, {
        "try|help ",
        arg,
        "|catch /^Vim(help):E149/|call nvim_win_close(",
        state.win,
        ", v:false)|echoerr v:exception|endtry",
    })
    -- Scheduled, because `nvim_win_close` requires waiting for released textlock.
    vim.schedule(function() vim.cmd(table.concat(cmdparts)) end)
    api.nvim_set_option_value("filetype", "help", { buf = state.buf }) -- Set ft again to redraw conceal formatting.
    state.title = "help"
    set_state(state)
end

function Haunt.man(opts)
    local state = get_state()
    local arg = fn.expand("<cword>")
    if (opts and vim.tbl_count(opts.fargs) > 0) then arg = opts.fargs[1] end
    if #arg <= 0 then
        warn(":Man requires an argument")
        return
    end
    state.buf, state.win = floating(state.buf, state.win, "nofile", "man", "man")
    lock_to_win(state.buf, state.win)
    local cmdparts = {}
    if (opts and opts.bang) then
        cmdparts = { "Man!" }
    else
        cmdparts = {
            "try|Man ",
            arg,
            "|catch /man.lua: /|call nvim_win_close(",
            state.win,
            ", v:false)|echoerr v:exception|endtry",
        }
    end
    -- Scheduled, because `nvim_win_close` requires waiting for released textlock.
    vim.schedule(function() vim.cmd(table.concat(cmdparts)) end)
    state.title = "man"
    set_state(state)
end

if Haunt.config.define_commands then
    command("HauntTerm", Haunt.term,
        {
            nargs = "*",
            complete = "shellcmd",
            desc = "Create or restore floating terminal, optionally setting a title or running a command"
        })
    command("HauntLs", Haunt.ls,
        {
            nargs = 0,
            bang = true,
            desc = "Show mapping of floating (or all, if using !) terminal titles -> buffer numbers"
        })
    command("HauntHelp", Haunt.help,
        {
            nargs = "?",
            complete = "help",
            desc = "Open neovim help of argument or word under cursor in floating window"
        })
    command("HauntMan", Haunt.man, {
        nargs = "?",
        bang = true,
        complete = function(arg_lead, cmdline, cursor_pos)
            local man = load("man")
            if man then
                return man.man_complete(arg_lead, cmdline, cursor_pos)
            end
        end,
        desc = "Show man page of argument (or current file if using !) or word under cursor in floating window"
    })
end

return Haunt
