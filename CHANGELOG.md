# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.2] — 2025-01-19

### Fixed
- Missing entries in `:HauntLs!`/`require('haunt').ls({ bang = true })` output
  due to incorrect reliance on non-unique `b:term_title` to identify terminal
  buffers

### Added
- `<Plug>(haunt-send)` mapping target to facilitate sending whole buffers,
  selected lines, or the fenced code block surrounding the cursor (for markdown
  buffers) to a running interpreter with `job-id` matching either `v:count` or
  the cached `t:HauntState.channel` value
- `:verbose` command modifier support for `:HauntLs[!]`, providing a tabular
  output that includes the `job-id` and `b:term_title` for each listed terminal
  buffer

### Changed
- `:HauntLs!`/`require('haunt').ls({ bang = true })` output now looks identical
  to the non-bang variant for all floating terminals, and non-floating
  terminals are listed using their `job-id` instead of relying on the
  non-unique `b:term_title`

## [2.2.1] — 2024-09-26

### Fixed
- NeoVim 0.9 support

## [2.2.0] — 2024-08-23

### Fixed
- Sticky buffers regression due to `5be1155`.
- Incorrect implementation of `define_commands` setup option.

### Added
- Ability to close help buffers with `q` (can be disabled with `setup`).
- Automatic terminal mode for floating terminals (using `startinsert`)

### Changed
- Bare `require('haunt')` is no longer enough to initialise, you **must** call
  `setup()`.

## [2.1.0] — 2024-08-20

### Added
- Silent mode for `Haunt.ls` API (return list, don't print).
- Bypass `'winfixbuf'` setter/getter on NeoVim versions < 0.10.

### Fixed
- Some missing nil-checks for API usage.
- Some edge case bugs in `Haunt.man`.
- `Haunt.man{ bang = true }`, i.e. `:HauntMan!`, not working at all

## [2.0.0] — 2024-08-18

### Added
- Comprehensive test suite using [mini.nvim](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md) by @echasnovski, closing [#1](https://todo.sr.ht/~adigitoleo/nvim-plugins/1)
- `Haunt.reset()` (and `:HauntReset`) which can be used to recover from
  corrupted tab-local state

### Fixed
- Conditional logic to determine when new buffers need to be created
- Buffer locking (sticky buffers) using `'winfixbuf'`, requires NeoVim 0.10,
  see <https://github.com/neovim/neovim/issues/12517> and
  <https://github.com/neovim/neovim/pull/27738>
- Adapt to NeoVim 0.10 deprecations.

## [1.2.1] — 2024-07-24

### Fixed
- Regression causing inability to run `:HauntMan` or `:HauntHelp` at all.

## [1.2.0] — 2024-07-24

### Added
- Test suite, using bespoke framework.

### Fixed
- Configuration validation.
- Allowed calling all API functions without an argument (default behaviours
  clarified in `:help heunt-api`).

## [1.1.5] — 2024-05-03

### Fixed
- Bug which caused the second call to `:HauntLs` to error.

## [1.1.4] — 2024-05-03

### Fixed
- Use a more robust method to get `term_title` of terminal buffers.

## [1.1.3] — 2024-05-03

### Fixed
- Missing argument to `getbufvar` in `Haunt.ls()`.

## [1.1.2] — 2024-05-02

### Fixed
- Broken `.setup()` method due to undefined reference to `.close()`.

## [1.1.1] — 2024-04-30

### Fixed
- Bug in 1.1.0 release which prevented `:HauntHelp` from working.

## [1.1.0] — 2024-04-30

### Added
- `:HauntLs!` command to show `b:term_title`s of all terminal buffers, not just
  those in floating windows (listed in `Haunt.state`).

## [1.0.0] — 2024-04-29

## [0.2.0] — 2024-04-29

## [0.1.0] — 2024-04-29

[2.2.2]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v2.2.2
[2.2.1]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v2.2.1
[2.2.0]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v2.2.0
[2.1.0]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v2.1.0
[2.0.0]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v2.0.0
[1.2.1]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.2.1
[1.2.0]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.2.0
[1.1.5]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.1.5
[1.1.4]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.1.4
[1.1.3]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.1.3
[1.1.2]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.1.2
[1.1.1]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.1.1
[1.1.0]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.1.0
[1.0.0]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v1.0.0
[0.2.0]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v0.2.0
[0.1.0]: https://git.sr.ht/~adigitoleo/haunt.nvim/refs/v0.1.0
