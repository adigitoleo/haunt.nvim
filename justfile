test: mini-nvim
	@echo "··· Running test suite ···"
	nvim --headless --noplugin -u ./test/init.lua -c "lua MiniTest.run()"

test_file file: mini-nvim
	@echo "··· Running test file {{file}} ···"
	nvim --headless --noplugin -u ./test/init.lua -c "lua MiniTest.run_file('{{file}}')"

[private]
mini-nvim:
	@echo "··· Downloading test suite dependencies ···"
	test -d dep/mini.nvim/.git || git submodule update --init --recursive

clean:
	git submodule deinit -f dep/mini.nvim && rm -rf .git/modules/dep/mini.vim
	rm -rf doc/tags
