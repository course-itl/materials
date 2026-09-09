#!/usr/bin/env python3
"""gen.py — генератор тестов для учебной задачи «сумма чисел».

Интерфейс любого генератора курса: сид — первый аргумент, тест — в stdout.
Одинаковый сид → одинаковый тест: контртест можно воспроизвести по номеру.

    ./gen.py 42
"""
import random
import sys

seed = int(sys.argv[1])
random.seed(seed)

n = random.randint(1, 10)
print(n)
print(*[random.randint(-100, 100) for _ in range(n)])
