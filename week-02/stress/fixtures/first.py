#!/usr/bin/env python3
# first.py — «индекс максимума»: печатает 1-based индекс ПЕРВОГО максимума. Верно.
import sys

data = sys.stdin.read().split()
n = int(data[0])
a = [int(x) for x in data[1:1 + n]]
print(a.index(max(a)) + 1)
