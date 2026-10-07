#!/usr/bin/env python3
"""chk.py — чекер для задачи «индекс максимума».

Интерфейс чекера курса (совместим с testlib):
    chk.py <input> <output> <answer>
input  — тест, output — проверяемый ответ, answer — ответ эталонного решения.
Код выхода 0 — ответ принят, любой другой — отвергнут; причина — в stderr.
"""
import sys


def main() -> int:
    inp, out, ans = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(inp) as f:
        data = f.read().split()
    n = int(data[0])
    a = [int(x) for x in data[1:1 + n]]

    with open(out) as f:
        tokens = f.read().split()
    if len(tokens) != 1 or not tokens[0].lstrip("-").isdigit():
        print(f"WA: ожидалось одно целое число, получено {tokens!r}", file=sys.stderr)
        return 1
    idx = int(tokens[0])
    if not 1 <= idx <= n:
        print(f"WA: индекс {idx} вне диапазона 1..{n}", file=sys.stderr)
        return 1
    if a[idx - 1] != max(a):
        print(f"WA: a[{idx}] = {a[idx - 1]}, а максимум = {max(a)}", file=sys.stderr)
        return 1
    # answer (ответ эталона) здесь не нужен: правильность проверяется по входу.
    # Но файл обязан существовать — таков интерфейс.
    open(ans).close()
    print("OK", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
