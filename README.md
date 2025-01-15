# 👻 haunt.nvim

Floating windows for terminals, man pages and help buffers.

> **haunt** (noun):
>   *a place frequented by a specified person or group of people*

This [NeoVim](https://neovim.io) plugin, written in Lua, offers alternative
commands to open embedded terminals, man pages and help buffers in floating
windows. Existing terminal buffers can also be opened in the floating window.
Commands like `:bnext`, `:bprevious`, `:b#` etc. are suppressed in this window.
Buffer contents, selected lines, and fenced code blocks in markdown buffers
can be sent to a terminal job, all using a single key sequence.
**This plugin is currently tested on latest NeoVim on Arch Linux.**
Check [this link](https://archlinux.org/packages/extra/x86_64/neovim/) to
discover the recommended NeoVim version.

See [this link](https://adigitoleo.srht.site/haunt-nvim/haunt-nvim.mp4) for a demo video.

![:HauntHelp screenshot](screenshot.png)

## Setup

Install the plugin using your preferred plugin manager. Alternatively, NeoVim
can load packages if they are added to your [`'packpath'`](https://neovim.io/doc/user/options.html#'packpath').

To load the package without a plugin manager use the lua command `require('haunt').setup()`.
Default options are applied automatically, including floating window appearance
and command definitions. To omit definition of user-commands, use:

    require('haunt').setup { define_commands = false }

Available commands, mappings and options are described in `:help haunt`
(or `:HauntHelp haunt` if you allowed default command definitions).

## Contributing

New versions are generally developed on the `dev` branch.
Please send patches/queries to my [public inbox](https://lists.sr.ht/~adigitoleo/public-inbox).
Current issues and pending feature requests are listed on [my nvim-plugins tracker](https://todo.sr.ht/~adigitoleo/nvim-plugins?search=%5Bhaunt.nvim%5D).
Developers should download the [just](https://github.com/casey/just) command runner.
The source code includes a test suite which can be run using `just test`.
Running the test suite for the first time requires an internet connection,
because test suite dependencies need to be downloaded.
The test suite can also be run interactively by opening NeoVim with

    nvim -u test/init.lua

And running `:TestInit|TestRun`. The current CI test status is shown below:

[![builds.sr.ht status](https://builds.sr.ht/~adigitoleo/haunt.nvim.svg)](https://builds.sr.ht/~adigitoleo/haunt.nvim?)

Some developer notes and tentative feature suggestions are also included in
[this blog post](https://adigitoleo.srht.site/haunt-nvim/).

### Examples

Open the documentation for this plugin in a floating window:

    :HauntHelp haunt

Open a floating terminal called "scratch", run command, close it, and restore:

    :HauntTerm -t scratch
    :startinsert
    echo "scratch"<Cr>
    <C-\><C-n>
    :quit
    :HauntTerm -t scratch

Switch between two different interactive Python sessions:

    :HauntTerm -t py1 python
    :startinsert
    print("py1")<Cr>
    <C-\><C-n>
    :HauntTerm -t py2 python
    :startinsert
    print("py2")<Cr>
    <C-\><C-n>
    :HauntTerm -t py1

Open the man page for `mandoc(1)` in a floating window:

    :HauntMan mandoc

### Similar plugins

- [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) by @akinsho
  only provides floating windows for terminals, as part of a larger terminal
  buffer manipulation suite, and does not use sticky buffers
- [floating-help.nvim](https://github.com/Tyler-Barham/floating-help.nvim) by @Tyler-Barham
  doesn't have floating terminals but offers more control over the floating
  window position and layout; it currently doesn't use sticky buffers
- [FTerm.nvim](https://github.com/numToStr/FTerm.nvim) only offers floating windows for terminals,
  but doesn't seem maintained anymore and doesn't respect `vim.o.shell`
- [vim-floaterm](https://github.com/voldikss/vim-floaterm) also only offers floating terminals, and is written in
  vimscript and therefore supports Vim as well as NeoVim; it also offers a
  more complicated user-command which allows distinct appearance configurations
  for different terminals, however the implementations are a bit old and there
  are long-standing bugs that have proven tricky to resolve
- [floating-help](https://github.com/nil70n/floating-help) by @nil70n only
  offers floating windows for helpfiles, not man pages or terminals; the plugin
  itself doesn't have a helpfile or tests, and doesn't use sticky buffers
