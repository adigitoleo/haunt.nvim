Tests can be run offline simply via: `XDG_CONFIG_HOME=_testvar/ nvim -l test/run.lua`.
To run a particular test file, for debugging purposes, follow these steps:
- Generate the fixtures: `nvim -l test/genfixtures.lua`
- Run the test setup, e.g `XDG_CONFIG_HOME=_testvar/ nvim --headless -n -u test/init-pckr.lua -c quit`
- Run the main test file, e.g. `XDG_CONFIG_HOME=_testvar/ nvim -u -n test/test-pckr.lua`
