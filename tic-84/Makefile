all: tic-84.min.tic
	ls -l $<

run: tic-84.min.tic
	tic80 --skip $<
	ls -l $<

run-nocomp: tic-84.lua
	tic80 --skip $<

tic-84.min.tic: tic-84.min.lua tic80packer.py
	./tic80packer.py $< Y N AAAAAA AA00AA 666666 660066 FF0000 FFFFFF

tic-84.min.lua: tic-84.lua minify.lua
	lua minify.lua minify $< > $@
