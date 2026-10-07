#!/usr/bin/env python3
# last.py — «индекс максимума»: печатает 1-based индекс ПОСЛЕДНЕГО максимума. Тоже верно.
import sys

data = sys.stdin.read().split()
n = int(data[0])
a = [int(x) for x in data[1:1 + n]]
best = max(a)
print(max(i + 1 for i, x in enumerate(a) if x == best))
