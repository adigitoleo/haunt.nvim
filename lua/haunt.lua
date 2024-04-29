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
    termbufs = {}, -- maps known terminal 'titles' to their buffer IDs
}

local function warn(msg) api.nvim_err_writeln("[haunt.nvim]: " .. msg) end
local function is_executable(cmd) if fn.executable(cmd) > 0 then return true else return false end end

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
    local cfg = Haunt.config
    local option = key .. " = " .. value
    if section then
        option = table.concat({ section, key }, ".") .. " = " .. value
        if section == "window" and cfg.window[key] ~= nil then
            if (key == "width_frac" or key == "height_frac" or key == "winblend" or key == "zindex") and not type(value) == "number" then
                warn(option .. " must be a number")
                return cfg[section][key]
            elseif key == "show_title" and not type(value) == "boolean" then
                warn(option .. " must be a boolean")
                return cfg[section][key]
            elseif key == "title_pos" and not (value == "left" or value == "right" or value == "center" or value == nil) then
                warn(option .. " must be one of: 'left', 'right', 'center' or nil")
            elseif key == "border" and not type(key) == "string" then
                warn(option .. " must be a string")
            end
        end
    elseif key == "define_commands" and not type(value) == "boolean" then
        warn(option .. " must be a boolean")
    else
        warn("unrecognized config option " .. option)
    end
    return value
end

-- Setup function to allow and validate user configuration.
function Haunt.setup(config)
    Haunt.close()
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

-- Open or focus floating window and set {buf|file}type.
local function floating(buf, win, bt, ft, title)
    -- buf: possibly existing buffer
    -- win: possibly existing window
    -- bt: desired buftype
    -- ft: desired filetype
    -- title: title to be displayed in the window border
    local wc = vim.o.columns
    local wl = vim.o.lines
    local width = math.ceil(wc * 0.8)
    local height = math.ceil(wl * 0.8 - 4)
    if not api.nvim_buf_is_valid(buf) then
        buf = api.nvim_create_buf(true, false)
    end
    if bt ~= "terminal" then -- Ignore bt = "terminal" which is not allowed.
        api.nvim_buf_set_option(buf, "buftype", bt)
        api.nvim_buf_set_option(buf, "filetype", ft)
    end
    -- Need to recreate the window to update its title.
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, false) end
    win = api.nvim_open_win(buf, true, {
        border = "single",
        relative = "editor",
        style = "minimal",
        width = width,
        height = height,
        col = math.ceil((wc - width) * 0.5),
        row = math.ceil((wl - height) * 0.5 - 1),
        title = Haunt.config.window.show_title and title or nil,
        title_pos = Haunt.config.window.title_pos,
    })
    api.nvim_win_set_option(win, "winblend", Haunt.config.window.winblend)
    api.nvim_set_current_win(win)
    api.nvim_set_current_buf(buf)
    return buf, win
end

-- Don't allow switching buffers of the floating window except via our API.
local function lock_to_win(buf, win)
    api.nvim_create_autocmd({ "BufWinLeave" },
        {
            buffer = buf,
            callback = function(ev)
                vim.schedule(function()
                    if api.nvim_win_is_valid(win) then api.nvim_set_current_buf(ev.buf) end
                end)
            end
        })
end

local function get_state()
    local state = {}
    if vim.t.HauntState == nil then
        state = vim.tbl_deep_extend("force", state, Haunt.state)
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

function haunt_term(opts)
    local state = get_state()
    local title = nil
    local cmd = { vim.o.shell }
    local termbuf = -1
    if opts.fargs[1] == "-t" then -- Pick up explicit titles set with -t <title>.
        table.remove(opts.fargs, 1)
        title = opts.fargs[1]
        if title ~= nil then
            table.remove(opts.fargs, 1)
        else
            termfail("missing argument for -t", state)
            return
        end
    end
    if vim.tbl_count(opts.fargs) > 0 then cmd = opts.fargs end
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
    if create_new then
        fn.termopen(cmd, {
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
    set_state(state)
end

function haunt_ls(opts)
    if opts.bang then return end -- TODO: Use bang to also show non-haunt terminal buffers?
    local terminals = {}
    if vim.t.HauntState ~= nil then
        for k, v in pairs(vim.t.HauntState.termbufs) do
            if api.nvim_buf_is_valid(v) then
                terminals[k] = v
            end
        end
        vim.t.HauntState = terminals -- Take the opportunity to clean up dead buffer refs.
    end
    vim.print(vim.inspect(terminals))
end

function haunt_help(opts)
    local state = get_state()
    local arg = fn.expand("<cword>")
    if vim.tbl_count(opts.fargs) > 0 then arg = opts.fargs[1] end
    state.buf, state.win = floating(state.buf, state.win, "help", "help", "help")
    local cmdparts = {}
    if opts.bang then
        table.insert(cmdparts, "try|help! ")
    else
        table.insert(cmdparts, "try|help ")
    end
    cmdparts = vim.tbl_extend("keep", cmdparts, {
        nil, -- Replaced with try|help[!] from above.
        arg,
        "|catch /^Vim(help):E149/|call nvim_win_close(",
        state.win,
        ", v:false)|echoerr v:exception|endtry",
    })
    vim.cmd(table.concat(cmdparts))
    api.nvim_buf_set_option(state.buf, "filetype", "help") -- Set ft again to redraw conceal formatting.
    set_state(state)
end

function haunt_man(opts)
    local state = get_state()
    local arg = fn.expand("<cword>")
    if vim.tbl_count(opts.fargs) > 0 then arg = opts.fargs[1] end
    state.buf, state.win = floating(state.buf, state.win, "nofile", "man", "man")
    local cmdparts = {}
    if opts.bang then
        cmdparts = { "Man!" }
    else
        cmdparts = {
            "try|Man ",
            arg,
            '|catch /man.lua: /|call nvim_win_close(',
            state.win,
            ", v:false)|echoerr v:exception|endtry",
        }
    end
    vim.cmd(table.concat(cmdparts))
    set_state(state)
end

if Haunt.config.define_commands then
    command("HauntTerm", haunt_term,
        {
            nargs = "*",
            complete = "shellcmd",
            desc =
            "Create or restore floating terminal, optionally setting a title or running a command"
        })
    command("HauntLs", haunt_ls,
        { nargs = 0, desc = "Show mapping of floating terminal titles -> buffer numbers" })
    command("HauntHelp", haunt_help,
        {
            nargs = "?",
            complete = "help",
            bang = true,
            desc =
            "Open neovim help of argument or word under cursor in floating window"
        })
    command("HauntMan", haunt_man, {
        nargs = "?",
        bang = true,
        complete = function(arg_lead, cmdline, cursor_pos)
            local man = load("man")
            if man then
                return man.man_complete(arg_lead, cmdline, cursor_pos)
            end
        end,
        desc = "Show man page of argument or word under cursor in floating window"
    })
end

return Haunt
