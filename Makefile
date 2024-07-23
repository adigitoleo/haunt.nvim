.SHELLFLAGS += -u
.ONESHELL:
MAKEFLAGS += --no-builtin-rules
FILE =  $(error "specify the test file using a FILE=<name> assignment")

test: dep/mini.nvim/.git
	@echo "··· Running test suite ···"
	nvim --headless --noplugin -u ./test/init.lua -c "lua MiniTest.run()"

test_file: dep/mini.nvim/.git
	@echo "··· Running test file $(FILE) ···"
	nvim --headless --noplugin -u ./test/init.lua -c "lua MiniTest.run_file('$(FILE)')"

dep/mini.nvim/.git:
	@echo "··· Downloading test suite dependencies ···"
	git submodule update --init --recursive

.PHONY: test test_file clean
clean:
	git submodule rm deps/mini.nvim
	git commit
