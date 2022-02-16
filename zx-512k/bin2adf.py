#!/usr/bin/python

import struct, sys

ADFSize = 0x200 * 11 * 2 * 80
BootBlockSize = 0x400
HeaderSize = 0xC
DiskType = b"DOS\0"
RootBlock = 880

raw_bin = open(sys.argv[1], "rb").read()

bytes_used = HeaderSize + len(raw_bin)
bytes_left = BootBlockSize - bytes_used

if bytes_left < 0:
    sys.exit(f"Code exceeds bootblock limit by {-bytes_left} bytes")

print(f"{bytes_used} bytes used")

bootblock = bytearray(DiskType)
bootblock.extend(b'\0' * 4)
bootblock.extend(RootBlock.to_bytes(4, byteorder="big"))
bootblock.extend(raw_bin)
bootblock.extend(b'\0' * bytes_left)

u32_max = (1 << 32) - 1
checksum = 0

for data in struct.iter_unpack(">I", bootblock):
    if u32_max - checksum < data[0]:
        checksum += 1

    checksum = (checksum + data[0]) & u32_max

checksum = (~checksum) & u32_max

bootblock[4:8] = checksum.to_bytes(4, byteorder="big")

adf_bin = bootblock
adf_bin.extend(b'\0' * (ADFSize - BootBlockSize))

open(sys.argv[2], "wb").write(adf_bin)
