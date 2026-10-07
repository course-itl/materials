#!/usr/bin/env python3
# wa.py — решение «суммы чисел» с багом: при n >= 7 теряет последнее число.
# Учебная заглушка: на ней проверяется, что stress.sh ловит WA.
import sys

data = sys.stdin.read().split()
n = int(data[0])
nums = [int(x) for x in data[1:1 + n]]
if n >= 7:
    nums = nums[:-1]
print(sum(nums))
