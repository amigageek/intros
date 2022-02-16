#!/usr/bin/python

# based on this one, from Gargaj
#
# https://gist.github.com/Gargaj/5bf66c128c6c6c47f4c78de630e56569
#
# TIC80 packer
#
#  Uses the zlib code chunk to crunch down your source
#  https://github.com/nesbox/TIC-80/wiki/tic-File-Format
#
# Usage: tic80packer [lua file]
#

from enum import Enum
import os
import sys
import zlib
# specifically for gzthermal
import gzip
import subprocess

zopfli_installed = False
try:
    import zopfli
    print("module 'zopfli' is installed")
    zopfli_installed = True
except ModuleNotFoundError:
    print("module 'zopfli' is not installed")
    zopfli_installed = False


# this one is specifically for gzthermal
# https://encode.su/threads/1889-gzthermal-pseudo-thermal-view-of-Gzip-Deflate-compression-efficiency
def create_thermal_image(uncompdata: bytes):
    try:
        outputFilenameGZ = "gzthermal.gz"
        gzthermalfile = "gzthermal-result.png"
        with gzip.open(outputFilenameGZ, 'wb') as f:
            f.write(uncompdata)
        os.system("gzthermal.exe " + outputFilenameGZ)
        if sys.platform.startswith('linux'):
            ret_code = subprocess.call(['xdg-open', gzthermalfile])
        elif sys.platform.startswith('darwin'):
            ret_code = subprocess.call(['open', gzthermalfile])
        elif sys.platform.startswith('win'):
            ret_code = subprocess.call(['start', gzthermalfile], shell=True)
        else:
            print("unknown platform found, don't know how to view an image via OS")
    except:
        print("problems with using gzthermal or create_thermal_image()")


# what do we want?
# - the filename
# - whether or not we should use the compressed or uncompressed
# - whether we should force the chunk-default header
# - whether we should truncate the chunk-default header.
# these can be reduced to
# - filename
# - compressed? -> no/yes/auto
# - force chunk-default? -> no/yes/truncate

# low-hanging fruit: replace windows crlf -> cr
UNIX_NEWLINE = b'\n'
WINDOWS_NEWLINE = b'\r\n'
MAC_NEWLINE = b'\r'

UNIX_NEWLINE_ascii = '\n'
WINDOWS_NEWLINE_ascii = '\r\n'
MAC_NEWLINE_ascii = '\r'

class Compression(Enum):
    N = 0  # No
    Y = 1  # Yes
    A = 2  # Automatic: chooses the smallest size

    @classmethod
    def has_key(cls, key):
        return key in cls.__members__
        # alternative
        # return key in cls._member_names_

    @classmethod
    def has_value(cls, value):
        return value in cls._value2member_map_


class ChunkDefault(Enum):
    N = 0  # No
    Y = 1  # Yes
    T = 2  # Truncated header

    @classmethod
    def has_key(cls, key):
        return key in cls.__members__
        # alternative
        # return key in cls._member_names_

    @classmethod
    def has_value(cls, value):
        return value in cls._value2member_map_


# useless defaults
filename = None
compression = Compression.A
chunkDefault = ChunkDefault.T
codeChunkType = None  # important that this one is set correctly for compressed or uncompressed code
palette = None

if len(sys.argv) >= 3:
    filename = sys.argv[1]
    compression = Compression[sys.argv[2][0].upper()]
    chunkDefault = ChunkDefault[sys.argv[3][0].upper()]

    if len(sys.argv) >= 4:
        palette = []

        for i in range(4, len(sys.argv)):
            palette.extend(bytes.fromhex(sys.argv[i]))

elif len(sys.argv) > 1:
    filename = sys.argv[1]
else:  # well, what else is there to do?
    if filename is None:
        print("Usage: (python3) tic80packer.py <filename> <Compression:NO/YES/AUTO> <ChunkDefault:NO/YES/TRUNCATED>")
        print("If no filename is given it runs in interactive mode")
        filename = input("filename: ")

        sTemp = None
        while not Compression.has_key(sTemp):
            sTemp = input("use compression N(O) / Y(ES) / A(UTO): ")
            if len(sTemp) > 0:
                sTemp = sTemp[0].upper()
        compression = Compression[sTemp]

        sTemp = None
        while not ChunkDefault.has_key(sTemp):
            sTemp = input("use Default Chunk? N(O) / Y(ES) / T(RUNCATED): ")
            if len(sTemp) > 0:
                sTemp = sTemp[0].upper()
        chunkDefault = ChunkDefault[sTemp]

with open(filename, mode='rb') as file:
    uncomp = file.read().replace(WINDOWS_NEWLINE, UNIX_NEWLINE).replace(MAC_NEWLINE, UNIX_NEWLINE)
uncomp_size = len(uncomp)

minified = ""
with open(filename, mode='r') as file:
    for line in file.readlines():
        trimmed_line = " ".join((line.strip()).replace('\t', ' ').split()).replace(WINDOWS_NEWLINE_ascii, UNIX_NEWLINE_ascii).replace(
            MAC_NEWLINE_ascii, UNIX_NEWLINE_ascii)
        if (len(trimmed_line) != 0) & (not trimmed_line.startswith("--")):
            minified += trimmed_line + UNIX_NEWLINE_ascii
# remove that last return-code
minified = minified[:-1]
minified_size = len(minified)

splitname = os.path.splitext(filename)
with open(splitname[0]+"_trimmed"+splitname[1], "w+", newline="\n") as file:
    file.write(minified)
    file.flush()

# switch the original file with the minified
uncomp = minified.encode("ascii")

# create baseline of NO compression
# comp = zlib.compress(uncomp, zlib.Z_BEST_COMPRESSION)
comp = zlib.compress(uncomp, 0)
comp_size = len(comp)

bestcompression_level = 0
bestcompression_strategy = 0

# testing with different compression_levels
# for i in range(0, 10):
#     new_compressed_data = zlib.compress(uncomp, i)
#     new_compressed_size = len(new_compressed_data)
#     if new_compressed_size < comp_size:
#         bestcompression_level = i
#         comp = new_compressed_data
#         comp_size = new_compressed_size

# testing with compressobj, compressionlevels, and strategies
# https://docs.python.org/3/library/zlib.html
for i1 in range(9, -1, -1):
    for i2 in range(0, 5):
        # i2 : zlib.Z_DEFAULT_STRATEGY, zlib.Z_FILTERED, zlib.Z_HUFFMAN_ONLY, zlib.Z_RLE, zlib.Z_FIXED
        compress_obj = zlib.compressobj(i1, zlib.DEFLATED, 15, zlib.DEF_MEM_LEVEL, i2)
        new_compressed_data = compress_obj.compress(uncomp)
        new_compressed_data += compress_obj.flush()
        # we dont want/need the checksum, so lets remove the last 4 bytes
        new_compressed_data = new_compressed_data[:-4]
        new_compressed_size = len(new_compressed_data)

        if new_compressed_size < comp_size:
            # these are more for during debugging... i was interested
            bestcompression_level = i1
            bestcompression_strategy = i2

            comp = new_compressed_data
            comp_size = new_compressed_size

# try the zopfli packer
# zopfli_installed = False
if zopfli_installed:
    c = zopfli.ZopfliCompressor(zopfli.ZOPFLI_FORMAT_ZLIB, False, 12000, 1, 0)
    new_compressed_data = c.compress(uncomp) + c.flush()
    # we dont want/need the checksum, so lets remove the last 4 bytes
    new_compressed_data = new_compressed_data[:-4]
    new_compressed_size = len(new_compressed_data)

    if new_compressed_size <= comp_size:
        bestcompression_level = 99
        bestcompression_strategy = 99
        comp = new_compressed_data
        comp_size = new_compressed_size

    # for good measure
    new_compressed_data = zopfli.zlib.compress(uncomp, 4)
    # we dont want/need the checksum, so lets remove the last 4 bytes
    new_compressed_data = new_compressed_data[:-4]
    new_compressed_size = len(new_compressed_data)

    if new_compressed_size < comp_size:
        bestcompression_level = 97
        bestcompression_strategy = 97
        comp = new_compressed_data
        comp_size = new_compressed_size

ratio_minified = (100.0 * (minified_size - comp_size) / minified_size)
ratio_wo_header = (100.0 * (uncomp_size - comp_size) / uncomp_size)
ratio_w_header = (100.0 * (uncomp_size - (comp_size + 4)) / uncomp_size)

print("")
print("Uncompressed length: {} bytes".format(uncomp_size))
print("Minified length:     {} bytes".format(minified_size))
print("Compressed length:   {} bytes, {:2.2f}%".format(comp_size, ratio_wo_header))
print("With header:         {} bytes, {:2.2f}%".format(comp_size + 4, ratio_w_header))
print("")

#create_thermal_image(uncomp)

# switch compression
sDataToWrite = None

if compression == Compression.A:
    if comp_size < uncomp_size:
        compression = Compression.Y
    else:
        compression = Compression.N

if compression == Compression.N:
    if uncomp_size > 64 * 1024:
        print("Warning: Uncompressed size is outside 64kB limit; Very possible it won't work")
        print("Will try compressed version")
        compression = Compression.Y
    else:
        print("Using uncompressed version")
        codeChunkType = bytes([5])
        sDataToWrite = uncomp

if compression == Compression.Y:
    print("Using compressed version")
    if comp_size > 64 * 1024:
        print("Warning: Compressed size is outside 64kB limit; Very possible it won't work")
    codeChunkType = bytes([16])
    sDataToWrite = comp

# https://github.com/nesbox/TIC-80/wiki/tic-File-Format
# header is 4 bytes large
# Header[0] -> 16 -> 0x10 -> (BBBCCCCC) 00010000d -> Chunktype: 16 (0x10) - ZLIB Compressed Code (0.80)
outputFilename = os.path.splitext(filename)[0]+'.tic'
with open(outputFilename, "wb+") as file:
    #  file.write(bytes([16]))
    file.write(codeChunkType)
    file.write(bytes([len(sDataToWrite) & 0xFF]))
    file.write(bytes([len(sDataToWrite) >> 8]))
    file.write(bytes([0]))
    file.write(sDataToWrite)

    # switch default chunk
    if chunkDefault == ChunkDefault.Y:
        # write full chunk
        print("Using full [Default] Chunk")
        file.write(bytes([17]))
        file.write(bytes([0]))
        file.write(bytes([0]))
        file.write(bytes([0]))
    elif chunkDefault == ChunkDefault.T:
        # write truncated chunk
        print("Using Truncated [Default] Chunk -> {0} bytes".format(comp_size + 5))
        file.write(bytes([17]))
    else:  # chunkDefault == ChunkDefault.N:
        # write no chunk
        print("Skipping [Default] Chunk")

    if palette:
        file.write(bytes([12, len(palette), 0, 0]))
        file.write(bytes(palette))

    # redundant because of With open(x) as file:
    file.close()

exit(0)
