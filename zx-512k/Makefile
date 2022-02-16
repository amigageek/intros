all: zx-512k.adf

zx-512k.adf: zx-512k.bin bin2adf.py
	./bin2adf.py $< $@

zx-512k.bin: zx-512k.s
	vasmm68k_mot -wfail -m68000 -Fbin -o $@ $<
