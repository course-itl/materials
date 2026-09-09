#!/usr/bin/env python3
# ok2.py — второе верное решение «суммы чисел», написанное иначе (цикл).
# Пара ok.py / ok2.py — «оба правильные»: stress.sh на них обязан молчать.

n = int(input())
total = 0
for x in input().split():
    total += int(x)
print(total)
