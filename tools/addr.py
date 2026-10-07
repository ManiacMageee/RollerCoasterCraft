#!/usr/bin/env python3
"""Dev helper: map a crash address in .text back to the NASM listing.
usage: tools/addr.py 0x404504"""
import re, sys
a = int(sys.argv[1], 16)
base = None
for line in open("build/main.map"):
    m = re.match(r"^ \.text\s+0x([0-9a-f]+)\s+0x[0-9a-f]+ build/main.obj", line)
    if m: base = int(m.group(1), 16); break
off = a - base
print("offset in .text: %X" % off)
sec, last, ctx = None, None, []
for line in open("build/main.lst"):
    if "section .text" in line: sec = "text"
    elif re.search(r"section \.(data|bss)", line): sec = "other"
    m = re.match(r"^\s*\d+\s+([0-9A-F]{8})\s", line)
    ctx.append(line.rstrip()); ctx = ctx[-12:]
    if m and sec == "text" and int(m.group(1), 16) > off and last is not None:
        print("\n".join(ctx)); break
    if m and sec == "text": last = int(m.group(1), 16)
