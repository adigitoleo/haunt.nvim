# 👻 haunt.nvim

Floating windows for terminals, man pages and help buffers.

> **haunt** (noun):
>   *a place frequented by a specified person or group of people*

This [NeoVim](https://neovim.io) plugin, written in Lua, offers alternative
commands to open embedded terminals, man pages and help buffers in floating
windows. Existing terminal buffers can also be opened in the floating window.
Commands like `:bnext`, `:bprevious`, `:b#` etc. are suppressed in this window.
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

Available commands and options are described in `:help haunt`
(or `:HauntHelp haunt` if you allowed default command definitions).

## Contributing

New versions are generally developed on the `dev` branch.
Please send patches/queries to my [public inbox](https://lists.sr.ht/~adigitoleo/public-inbox).
Current issues and pending feature requests are listed on [my nvim-plugins tracker](https://todo.sr.ht/~adigitoleo/nvim-plugins?search=%5Bhaunt.nvim%5D).
The source code includes a test suite which can be run using `make test`.
Running the test suite for the first time requires an internet connection,
because test suite dependencies need to be downloaded.
The test suite can also be run interactively by opening NeoVim with

    nvim -u test/init.lua

And running `:TestInit|TestRun`. The current CI test status is shown below:

[![builds.sr.ht status](https://builds.sr.ht/~adigitoleo/haunt.nvim.svg)](https://builds.sr.ht/~adigitoleo/haunt.nvim?)

Some developer notes and tentative feature suggestions are also included in
[this blog post](https://adigitoleo.srht.site/haunt-nvim/).

### Examples

*The following examples are formatted as successions of cmdline entries.*

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
