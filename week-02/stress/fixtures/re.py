#!/usr/bin/env python3
# re.py — решение «суммы чисел», которое падает при n == 4 (ненулевой код выхода).
# Учебная заглушка: на ней проверяется, что stress.sh отличает RE от WA.
import sys

data = sys.stdin.read().split()
n = int(data[0])
if n == 4:
    print("boom: something went wrong", file=sys.stderr)
    sys.exit(3)
print(sum(int(x) for x in data[1:1 + n]))
