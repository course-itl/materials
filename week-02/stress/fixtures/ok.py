#!/usr/bin/env python3
# ok.py — верное решение задачи «сумма чисел»: читает n и n чисел, печатает сумму.
import sys

data = sys.stdin.read().split()
n = int(data[0])
print(sum(int(x) for x in data[1:1 + n]))
