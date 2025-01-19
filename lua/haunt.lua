local api = vim.api
local fn = vim.fn
local sleep = (vim.uv or vim.loop).sleep
local command = api.nvim_create_user_command
local bindkey = vim.keymap.set
local Haunt = {}

local buf_invalid = 0 -- Error code from nvim_create_buf()
local win_invalid = 0 -- Error code from nvim_open_win()
local job_invalid = 0 -- One of the error codes from termopen(), the other is -1

-- Values of 0 for buffer/window ID are ambiguously used in the api
-- to indicate either an error or as an alias for the "current" buffer/window,
-- or sometimes even for the "alternate" buffer, e.g. :h bufname().
-- Here, we define some wrappers to remove the aliasing.

---@param win integer window ID, see |window-ID|
local function win_is_valid(win) return api.nvim_win_is_valid(win) and win ~= win_invalid end
---@param buf integer buffer number, as returned by |bufnr()|
local function buf_is_valid(buf) return api.nvim_buf_is_valid(buf) and buf ~= buf_invalid end

Haunt.config = {
    define_commands = true,   -- toggle to prevent definition of default user commands
    quit_help_with_q = true,  -- toggle to prevent definition of q -> :quit mapping in help buffers
    set_term_autocmds = true, -- toggle to prevent setting autocommands for opinionated terminal setup
    window = {
        width_frac = 0.8,     -- width of floating window as a fraction of total width
        height_frac = 0.8,    -- height of floating window as a fraction of total height
        winblend = 30,        -- transparency setting
        border = "single",    -- border style, see :h floatwin-api
        show_title = true,    -- show a title in the floating window border?
        title_pos = "left",   -- position for the border title, see :h api-floatwin
        zindex = 11,          -- floating window 'priority'
    },
}

Haunt.state = {        -- Local to a tabpage
    buf = buf_invalid, -- ID of the buffer currently displayed in the floating window
    win = win_invalid, -- ID of the floating window
    title = "",        -- Most recent title of the floating window
    termbufs = {},     -- Map of known terminal 'titles' and their buffer IDs
    channel = 0        -- Most recent |channel-id| used for Haunt.send
}

-- Use error(), which is blocking, instead of nvim_err_writeln(), which is not.
-- This is used in the test suite and could be useful for debugging.
Haunt._err_blocking = false
-- Track if user commands have been defined before.
Haunt._has_commands = false
-- Store ID for quit_help_with_q autocommand.
Haunt._quit_help_with_q = nil

---@param cmd string
local function is_executable(cmd) if fn.executable(cmd) > 0 then return true else return false end end
local function warn(msg) ---@param msg string
    local erf = api.nvim_err_writeln
    if Haunt._err_blocking then erf = error end
    erf("[haunt.nvim]: " .. msg)
end

-- Load either local or third-party plugin.
local function load(plugin) ---@param plugin string
    local has_plugin, out = pcall(require, plugin)
    if has_plugin then
        return out
    else
        warn("failed to load plugin '" .. plugin .. "'")
        return nil
    end
end

-- Validate custom user config, fall back to Haunt.config defaults.
---@param key string
---@param section string|nil
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
    elseif (key == "define_commands" or key == "quit_help_with_q" or key == "set_term_autocmds") and got_type ~= "boolean" then
        warn(option .. " must be a boolean")
        return schema[key]
    end
    return value
end

-- Setup function to allow and validate user configuration.
---@param config table
function Haunt.setup(config)
    if config ~= nil then
        for k, v in pairs(config) do
            if type(v) == "table" then
                for _k, _v in pairs(v) do
                    Haunt.config[k][_k] = validate(_k, _v, k)
                end
            else
                Haunt.config[k] = validate(k, v)
            end
        end
    end
    bindkey("n", "<Plug>(haunt-send)", function()
            local id = vim.v.count
            if id == 0 and vim.t.HauntState ~= nil then id = vim.t.HauntState.channel end
            require('haunt').send(id)
        end,
        {
            desc = "Send buffer/selected lines/fenced code block to job given by v:count or t:HauntState.channel"
        })
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
        command("HauntReset", Haunt.reset, {
            nargs = 0,
            desc = "Close floating window and reset internal state (attempt to recover from bugs)",
        })
        Haunt._has_commands = true
    elseif Haunt._has_commands == true then
        for _, cmd in pairs({ "HauntHelp", "HauntMan", "HauntTerm", "HauntLs", "HauntReset" }) do
            api.nvim_del_user_command(cmd)
        end
    end
    if Haunt.config.quit_help_with_q then
        Haunt._quit_help_with_q = api.nvim_create_autocmd({ "FileType" }, {
            pattern = "help",
            callback = function(ev) vim.keymap.set('n', 'q', function() vim.cmd("quit") end, { buffer = ev.buf }) end
        })
    elseif Haunt._quit_help_with_q ~= nil then
        api.nvim_del_autocmd(Haunt._quit_help_with_q)
    end
    if fn.has('nvim-0.10') == 0 then warn("using sticky buffers requires NeoVim 0.10 or later") end
    return Haunt
end

-- Get a copy of the tab-local vim.t.HauntState if not nil, or Haunt.state otherwise.
local function get_state() ---@return table
    local state = {}
    if vim.t.HauntState == nil then
        state = vim.deepcopy(Haunt.state)
        vim.t.HauntState = state
    else
        state = vim.tbl_deep_extend("force", state, vim.t.HauntState)
    end
    return state
end

-- (Re)draw the floating window. Not allowed when |textlock| is active.
---@param win integer ID of possibly existing window
---@param buf integer number of possibly existing buffer
---@param title string|nil optional title to use for terminal buffer reference
local function draw(win, buf, title) ---@return integer
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
        config.title_pos = config.title and Haunt.config.window.title_pos or nil
    end
    if not buf_is_valid(buf) then
        return win_invalid
    elseif win_is_valid(win) then
        api.nvim_win_set_config(win, config)
    else
        win = api.nvim_open_win(buf, true, config)
        if win == win_invalid then return win_invalid end
    end
    -- catch win=0, <https://github.com/neovim/neovim/discussions/30073#discussioncomment-10367494>
    if not win_is_valid(win) then warn("unable to draw invalid window") end
    api.nvim_set_option_value("winblend", Haunt.config.window.winblend, { win = fn.win_getid(win) })
    return win
end

-- Open or focus floating window and set {buf|file}type. Not allowed when |textlock| is active.
---@param buf integer number of possibly existing buffer
---@param win integer ID of possibly existing window
---@param bt string desired |'buftype'|
---@param ft string desired |'filetype'|
---@param title string|nil optional title to be displayed in the window border
local function floating(buf, win, bt, ft, title)
    -- New buffer if old one is gone, or we're switching from a terminal (cannot set 'buftype')
    -- New buffer any time that we are making a help or man buffer.
    if (
            not buf_is_valid(buf) -- NOTE: Keep this condition first, make sure buf=0 is handled upfront.
            or (bt ~= "terminal" and api.nvim_get_option_value("buftype", { buf = buf }) == "terminal")
            or (bt == "help")
            or (ft == "man")
        ) then
        buf = api.nvim_create_buf(true, false)
    end
    -- catch buf=0, <https://github.com/neovim/neovim/discussions/30073#discussioncomment-10367494>
    if not buf_is_valid(buf) then warn("unable to prepare invalid buffer") end
    if bt ~= "terminal" then -- Setting 'buftype' to "terminal" is not allowed, `draw` uses |termopen|.
        api.nvim_set_option_value("buftype", bt, { buf = buf })
        api.nvim_set_option_value("filetype", ft, { buf = buf })
    elseif Haunt.config.set_term_autocmds then
        api.nvim_create_autocmd(
            { "BufWinEnter", "TermOpen" },
            { buffer = buf, command = "startinsert|setlocal scrolloff=0|setlocal nonumber norelativenumber signcolumn=no" }
        )
    end
    win = draw(win, buf, title)
    -- catch win=0, <https://github.com/neovim/neovim/discussions/30073#discussioncomment-10367494>
    if not win_is_valid(win) then warn("unable to focus invalid window") end

    api.nvim_set_current_win(win)
    api.nvim_set_current_buf(buf)
    return buf, win
end

-- Unset 'winfixbuf' to allow switching the buffer using our API.
local function remove_fixbuf(state) ---@param state table
    if fn.has('nvim-0.10') == 0 then return state end
    if win_is_valid(state.win) then
        if api.nvim_get_option_value("winfixbuf", { win = state.win }) then
            api.nvim_set_option_value("winfixbuf", false, { win = state.win })
        end
    end
    return state
end

-- Make floating window respond to VimResized events.
local function add_resized_hook(buf) ---@param buf integer
    api.nvim_create_autocmd({ "VimResized" },
        {
            buffer = buf,
            callback = vim.schedule_wrap(function(ev)
                if win_is_valid(vim.t.HauntState.win) and buf_is_valid(ev.buf) then
                    draw(vim.t.HauntState.win, ev.buf)
                end
            end)
        })
end

-- Set tab-local state to a copy of the provided state.
local function set_state(state) ---@param state table
    if buf_is_valid(state.buf) and win_is_valid(state.win) and fn.has('nvim-0.10') == 1 then
        api.nvim_set_option_value("winfixbuf", true, { win = fn.win_getid(state.win) })
        add_resized_hook(state.buf)
    end
    vim.t.HauntState = vim.deepcopy(state)
end

-- Throw a warning/error with the message `msg` and set tab-local state to `state`.
---@param msg string
---@param state table
local function termfail(msg, state)
    warn(msg)
    set_state(state)
end

---@param opts table See |lua-guide-commands-create|
local function has_args(opts) return (opts and opts.fargs and vim.tbl_count(opts.fargs) > 0) end

-- Determine if buffer (given by its number) is a terminal.
---@param maybe_buf_number integer
local function is_terminal_buf(maybe_buf_number) ---@return boolean success, any result, any ... see pcall()
    if maybe_buf_number ~= nil and buf_is_valid(maybe_buf_number) then
        return fn.getbufvar(maybe_buf_number, "&buftype") == "terminal"
    else
        return false
    end
end

-- Implementation for :HauntTerm.
---@param opts table See |lua-guide-commands-create|
function Haunt.term(opts) ---@return integer|nil
    local state = remove_fixbuf(get_state())
    local title = nil
    local cmd = { vim.o.shell }
    local termbuf_new = buf_invalid
    local termbuf = buf_invalid
    local create_new = false
    local job_id = nil

    -- Argument handling.
    if (opts and opts.fargs and opts.fargs[1] == "-t") then -- Pick up explicit titles set with -t <title>.
        table.remove(opts.fargs, 1)
        title = opts.fargs[1]
        if title ~= nil then
            table.remove(opts.fargs, 1)
        else
            termfail("missing argument for -t", state)
            return
        end
    end

    -- Support for opening existing (non-floating) terminal buffers.
    if has_args(opts) then cmd = opts.fargs end
    local maybe_buf_number = tonumber(cmd[1], 10) -- Allow opening existing terminal buffers by buffer number.
    if maybe_buf_number ~= nil then
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

        -- Run executable in terminal and exit, unless executable is vim.o.shell.
    elseif is_executable(cmd[1]) then
        if title == nil then title = cmd[1] end -- Use the first arg (executable name) as the title by defualt.
        if is_terminal_buf(state.termbufs[title]) then
            termbuf = state.termbufs[title]
        else
            create_new = true
        end
    else
        termfail(cmd[1] .. " is not executable", state)
        return
    end

    -- Floating window creation and |termopen| call.
    termbuf_new, state.win = floating(termbuf, state.win, "terminal", "", title)
    if termbuf_new == buf_invalid or state.win == win_invalid then return job_invalid end
    if create_new then
        job_id = fn.termopen(cmd, {
            on_exit = function()
                Haunt.ls({}, true) -- To clean up the dead reference.
                if cmd[1] == vim.o.shell then
                    api.nvim_input("<Cr>")
                end
            end
        })
        -- Flatten possible error codes into job_invalid, we don't care why it failed here.
        if job_id == job_invalid or job_id == -1 then
            job_id = job_invalid
            warn("failed to open new terminal buffer")
            return job_id
        end
        state.termbufs[title] = termbuf_new
        state.buf = termbuf_new
    else
        state.termbufs[title] = termbuf
        state.buf = termbuf
    end
    state.title = title
    set_state(state)
    return job_id
end

-- Implementation for :HauntLs\[!\].
---@param opts table See |lua-guide-commands-create|
---@param silent boolean toggle use of vim.print() of return value
function Haunt.ls(opts, silent)
    local terminals = {}
    if vim.t.HauntState ~= nil then
        for k, v in pairs(vim.t.HauntState.termbufs) do
            if buf_is_valid(v) then
                terminals[k] = v
            end
        end
        vim.t.HauntState.termbufs = terminals -- Take the opportunity to clean up dead buffer refs.
    end
    if (opts and opts.bang) then              -- Use of ! means that non-floating terminals, identified by job-id, are included.
        vim.tbl_map(function(v) terminals[tostring(vim.bo[v].channel)] = v end,
            vim.tbl_filter(
                function(v)
                    if
                        fn.getbufvar(v, "&buftype") == "terminal"
                        and (vim.t.HauntState ~= nil and not vim.tbl_contains(vim.t.HauntState.termbufs, v))
                    then
                        return v
                    end
                    return false
                end, api.nvim_list_bufs()
            )
        )
    end
    if (opts and opts.smods and opts.smods.verbose > 0) then
        for k, v in pairs(terminals) do
            terminals[k] = {
                bufnr = v,
                job = vim.bo[v].channel,
                term_title = api.nvim_buf_get_var(v, "term_title") -- NOTE: b:term_title is non-unique.
            }
        end
    end
    if silent == nil or not silent then
        vim.print(vim.inspect(terminals))
    end
    return terminals
end

-- Implementation for :HauntHelp.
---@param opts table See |lua-guide-commands-create|
function Haunt.help(opts)
    local state = remove_fixbuf(get_state())
    local arg = fn.expand("<cword>")
    if has_args(opts) then arg = opts.fargs[1] end
    state.buf, state.win = floating(state.buf, state.win, "help", "help", "help")
    sleep(100) -- Wait for floating window to open.
    local cmdparts = {}
    -- Catch E149 (invalid help tag) and redirect to :help E149.
    -- This is less destructive and much easier to handle than closing the window.
    cmdparts = vim.tbl_extend("keep", cmdparts, {
        "try|help ",
        arg,
        "|catch /^Vim(help):E149/|help E149|echoerr v:exception|endtry",
    })
    vim.cmd(table.concat(cmdparts))
    -- Wait for :help to load and maybe change the buffer number.
    sleep(100)

    api.nvim_set_option_value("filetype", "help", { buf = state.buf }) -- Set ft again to redraw conceal formatting.
    state.title = "help"
    set_state(state)
end

-- Implementation for :HauntMan\[!\].
---@param opts table See |lua-guide-commands-create|
function Haunt.man(opts)
    local state = remove_fixbuf(get_state())
    local arg = fn.expand("<cword>")
    if has_args(opts) then arg = fn.join(opts.fargs, ' ') end
    if string.len(arg) < 1 or arg == '""' or arg == "'\"\"'" then
        warn(":Man requires an argument")
        return
    end
    state.buf, state.win = floating(state.buf, state.win, "nofile", "man", "man")
    sleep(100) -- Wait for floating window to open.
    local cmdparts = {}
    if (opts and opts.bang) then
        cmdparts = { "try|b#|Man!|catch /man.lua: /|Man nvim(1)|echoerr v:exception|endtry" }
    else
        -- Catch man.lua errors (e.g. no man page found) and redirect to man nvim.
        -- This is less destructive and much easier to handle than closing the window.
        -- TODO: Consider redirecting to :help :Man, and handling the buftype/filetype change.
        cmdparts = {
            "try|Man ",
            arg,
            "|catch /man.lua: /|Man nvim(1)|echoerr v:exception|endtry",
        }
    end
    vim.cmd(table.concat(cmdparts))
    -- Wait for :Man to load and maybe change the buffer number.
    sleep(100)

    state.title = "man"
    set_state(state)
end

-- Send whole buffer or fenced code block to a running terminal.
---@param id integer See |job-id|, optional (use vim.t.HauntState.channel otherwise)
local function send_whole(id)
    if vim.o.filetype == "markdown" then
        -- TODO: Trap error from the next line and re-raise using our warn()?
        vim.treesitter.language.add('markdown') -- Throws if markdown parser is not available.
        local parser = vim.treesitter.get_parser()
        -- Only parse visible lines to avoid negative performance impact.
        local tree = parser:parse({ 0, 0, vim.o.lines, vim.o.columns })[1]
        local root = tree:root()
        local cursor_row, _ = unpack(api.nvim_win_get_cursor(0))
        local thisblock = nil

        -- Recursively traverse 'section' type children of the root 'document' element in the tree.
        local function find_fenced_code(node)
            for i = 0, node:named_child_count() - 1 do
                local child = node:named_child(i)
                -- Extract 'fenced_code_block' children from the sections.
                if child:type() == "fenced_code_block" then
                    local start_row, _, end_row, _ = child:range()
                    if cursor_row - 1 >= start_row and cursor_row - 1 <= end_row then
                        thisblock = child
                    end
                elseif child:type() == "section" then
                    find_fenced_code(child)
                end
            end
        end

        find_fenced_code(root)
        if thisblock ~= nil then
            local start_row, _, end_row, _ = thisblock:range()
            api.nvim_chan_send(id, table.concat(api.nvim_buf_get_lines(0, start_row + 1, end_row - 1, true), '\n'))
        else
            warn("cursor is not in a code block")
        end
    else
        api.nvim_chan_send(id, table.concat(api.nvim_buf_get_lines(0, 0, -1, false), '\n'))
    end
end

-- Send buffer/lines or fenced code block (markdown files) to a running terminal.
---@param id integer See |job-id|
function Haunt.send(id)
    local state = get_state()
    if id == nil then
        id = state.channel
    elseif id ~= 0 then    -- Channel 0 is the parent nvim instance.
        state.channel = id -- Update channel-id AKA job-id cache.
        vim.t.HauntState = vim.deepcopy(state)
    else
        warn("cannot send data to channel 0")
        return
    end
    local mode = api.nvim_get_mode().mode
    if mode == 'n' then
        send_whole(id)
    elseif mode == 'V' then
        -- NOTE: Don't use '< and '> marks, because they are not set until the visual selection is terminated
        -- (and even in that case, I have found them to be unreliable).
        local start_line = fn.line("v")
        local end_line = fn.line(".")
        api.nvim_chan_send(id, table.concat(api.nvim_buf_get_lines(0, start_line - 1, end_line, true), '\n'))
    end
    api.nvim_chan_send(id, '\r')
end

-- Close floating window and reset tab-local state to defaults, except for the termbufs table.
function Haunt.reset()
    local state = remove_fixbuf(get_state())
    if buf_is_valid(state.buf) then
        local ft = api.nvim_get_option_value("filetype", { buf = state.buf })
        local bt = api.nvim_get_option_value("buftype", { buf = state.buf })
        if bt == "help" or ft == "man" then api.nvim_buf_delete(state.buf, { force = true }) end
    end
    if win_is_valid(state.win) then
        api.nvim_win_close(state.win, true)
    end
    state.buf = Haunt.state.buf
    state.win = Haunt.state.win
    state.title = Haunt.state.title
    vim.t.HauntState = state
end

return Haunt
