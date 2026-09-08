#!/usr/bin/env python3
"""Fail if any native library in an APK is not 16 KB page-size compatible.

Google Play requires 16 KB page support for apps targeting Android 15+, and an
Android 16 device refuses to treat an unaligned app as compatible (see
docs/00 Decision Log D16). Every PT_LOAD segment must be aligned to >= 16384.

    python3 tools/check_so_alignment.py path/to/app.apk
"""
from __future__ import annotations

import struct
import sys
import zipfile

REQUIRED_ALIGN = 16 * 1024


def load_aligns(data: bytes) -> list[int] | None:
    """Alignments of every PT_LOAD segment, or None if this is not an ELF."""
    if data[:4] != b"\x7fELF":
        return None
    is64 = data[4] == 2
    if is64:
        phoff = struct.unpack_from("<Q", data, 0x20)[0]
        phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
        align_off, fmt = 48, "<Q"
    else:
        phoff = struct.unpack_from("<I", data, 0x1C)[0]
        phentsize, phnum = struct.unpack_from("<HH", data, 0x2A)
        align_off, fmt = 28, "<I"
    aligns = []
    for i in range(phnum):
        off = phoff + i * phentsize
        if off + phentsize > len(data):
            return None
        if struct.unpack_from("<I", data, off)[0] == 1:  # PT_LOAD
            aligns.append(struct.unpack_from(fmt, data, off + align_off)[0])
    return aligns or None


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    bad = []
    checked = 0
    with zipfile.ZipFile(sys.argv[1]) as apk:
        for name in apk.namelist():
            if not name.endswith(".so"):
                continue
            aligns = load_aligns(apk.read(name))
            if not aligns:
                continue
            checked += 1
            worst = min(aligns)
            if worst < REQUIRED_ALIGN:
                bad.append((name, worst))
    print(f"checked {checked} native libraries")
    for name, align in sorted(bad):
        print(f"  NOT 16 KB compatible: {name} (align={align})")
    if bad:
        print("Upgrade the dependency that ships it; see docs/00 Decision Log D16.")
        return 1
    print("all libraries are 16 KB page-size compatible")
    return 0


if __name__ == "__main__":
    sys.exit(main())
