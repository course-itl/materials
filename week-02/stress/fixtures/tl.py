#!/usr/bin/env python3
# tl.py — решение «суммы чисел», которое «зависает» при n == 3 (спит 10 с).
# Учебная заглушка: на ней проверяется, что stress.sh умеет ограничивать время (-t).
import sys
import time

data = sys.stdin.read().split()
n = int(data[0])
if n == 3:
    time.sleep(10)
print(sum(int(x) for x in data[1:1 + n]))
