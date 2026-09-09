#!/usr/bin/env python3
"""gen-argmax.py — генератор для задачи «индекс максимума» (ответ не единственный).

Значения нарочно из маленького диапазона, чтобы максимум часто повторялся:
именно на таких тестах два верных решения дают разные ответы.
"""
import random
import sys

seed = int(sys.argv[1])
random.seed(seed)

n = random.randint(1, 6)
print(n)
print(*[random.randint(1, 3) for _ in range(n)])
