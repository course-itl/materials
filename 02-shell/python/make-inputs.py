#!/usr/bin/env python3
"""make-inputs.py — входные данные для разминок на Python (неделя 2).

    python3 make-inputs.py --out DIR [--seed S]

Создаёт в DIR:
    numbers.txt      — целые числа для stats.py (несколько на строку, с лишними пробелами)
    text.txt         — текст для topwords.py (кириллица и латиница, регистр, знаки препинания)
    tree/            — дерево каталогов для tree.py (в т.ч. скрытые и пустые файлы)
    files/           — три файла для sha.py
    checker-cases/   — наборы (input, output, answer, verdict) для checker.py (bonus)

Данные детерминированы сидом: одинаковый сид → одинаковые байты на любой
машине. По умолчанию сид фиксирован — на нём посчитаны эталонные хеши в
expected/. Свой сид пригодится, чтобы проверить решение на других данных.
"""
import argparse
import random
from pathlib import Path

WORDS_RU = ("конвейер поток скрипт сервер файл процесс сигнал терминал ядро строка "
            "команда каталог ключ архив права цикл функция переменная ошибка тест").split()
WORDS_EN = "shell pipe script bash python file process signal kernel loop diff seed".split()
PUNCT = ["", "", "", ",", ".", "!", "?", ":", ";", "...", ")", "\""]


def make_numbers(out: Path, rnd: random.Random) -> None:
    lines = []
    for _ in range(rnd.randint(30, 50)):
        k = rnd.randint(1, 8)
        nums = [rnd.randint(-1000, 1000) for _ in range(k)]
        sep = " " * rnd.randint(1, 3)
        lines.append(sep.join(str(x) for x in nums) + (" " if rnd.random() < 0.3 else ""))
    (out / "numbers.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def make_text(out: Path, rnd: random.Random) -> None:
    words = WORDS_RU + WORDS_EN
    weights = [rnd.randint(1, 20) for _ in words]
    parts = []
    for _ in range(400):
        w = words[weighted_index(rnd, weights)]
        style = rnd.random()
        if style < 0.15:
            w = w.upper()
        elif style < 0.45:
            w = w.capitalize()
        if rnd.random() < 0.05:
            w = w + "-" + rnd.choice(words)
        if rnd.random() < 0.06:
            w = w + str(rnd.randint(0, 99))
        parts.append(w + rnd.choice(PUNCT))
        if rnd.random() < 0.08:
            parts.append("\n")
    text = " ".join(parts).replace(" \n ", "\n")
    (out / "text.txt").write_text(text + "\n", encoding="utf-8")


def weighted_index(rnd: random.Random, weights: list[int]) -> int:
    # Своя реализация вместо random.choices: она проще и гарантированно одинакова во всех версиях Python.
    total = sum(weights)
    x = rnd.randint(1, total)
    for i, w in enumerate(weights):
        x -= w
        if x <= 0:
            return i
    return len(weights) - 1


def make_tree(out: Path, rnd: random.Random) -> None:
    root = out / "tree"
    layout = {
        "README.md": 1,
        "src/main.py": 1, "src/utils.py": 1, "src/parser.py": 1, "src/engine.cpp": 1,
        "src/.editorconfig": 1,
        "lib/helpers.py": 1, "lib/vendor/tiny.js": 1, "lib/vendor/deep/deeper/x.txt": 1,
        "tests/test_parser.py": 1, "tests/data/empty.txt": 0, "tests/data/big.bin": 1,
        ".cache/index": 1, ".gitignore": 1, "notes.txt": 1,
    }
    for rel, nonempty in layout.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        size = rnd.randint(1, 5000) if nonempty else 0
        if rel.endswith(".bin"):
            size = rnd.randint(6000, 9000)
            p.write_bytes(bytes(rnd.randint(0, 255) for _ in range(size)))
        else:
            p.write_text(("x" * (size - 1) + "\n") if size else "", encoding="utf-8")
    (root / "build" / "obj").mkdir(parents=True, exist_ok=True)   # пустой каталог: файлов в нём нет


def make_files(out: Path, rnd: random.Random) -> None:
    d = out / "files"
    d.mkdir(parents=True, exist_ok=True)
    (d / "one.txt").write_text("hello, week two\n" * rnd.randint(1, 5), encoding="utf-8")
    (d / "two.bin").write_bytes(bytes(rnd.randint(0, 255) for _ in range(rnd.randint(100, 300))))
    (d / "three.txt").write_text("", encoding="utf-8")


def best_segments(a: list[int]) -> tuple[int, list[tuple[int, int]]]:
    n = len(a)
    best = a[0]
    segs: list[tuple[int, int]] = []
    for l in range(n):
        s = 0
        for r in range(l, n):
            s += a[r]
            if s > best or not segs:
                best, segs = s, [(l + 1, r + 1)]
            elif s == best:
                segs.append((l + 1, r + 1))
    return best, segs


def make_checker_cases(out: Path, rnd: random.Random) -> None:
    base = out / "checker-cases"
    cases = []
    # 1–3: верный ответ, отличный от эталонного (или равный, если другого нет)
    while len(cases) < 3:
        n = rnd.randint(2, 7)
        a = [rnd.randint(-5, 5) for _ in range(n)]
        best, segs = best_segments(a)
        if len(segs) < 2:
            continue
        answer = segs[-1]
        other = rnd.choice(segs[:-1])
        cases.append((a, other, answer, "OK"))
    # 4: ответ совпадает с эталоном
    n = rnd.randint(1, 5)
    a = [rnd.randint(-5, 5) for _ in range(n)]
    best, segs = best_segments(a)
    cases.append((a, segs[-1], segs[-1], "OK"))
    # 5–6: отрезок с меньшей суммой
    while len(cases) < 6:
        n = rnd.randint(3, 7)
        a = [rnd.randint(-5, 5) for _ in range(n)]
        best, segs = best_segments(a)
        worse = [(l + 1, r + 1) for l in range(n) for r in range(l, n) if sum(a[l:r + 1]) < best]
        if not worse:
            continue
        cases.append((a, rnd.choice(worse), segs[-1], "WA"))
    # 7: выход за границы; 8: l > r; 9: не два числа
    n = 4
    a = [rnd.randint(-5, 5) for _ in range(n)]
    best, segs = best_segments(a)
    cases.append((a, (0, 2), segs[-1], "WA"))
    cases.append((a, (3, 2), segs[-1], "WA"))
    cases.append((a, (2,), segs[-1], "WA"))

    for i, (arr, output, answer, verdict) in enumerate(cases, 1):
        d = base / f"case{i:02d}"
        d.mkdir(parents=True, exist_ok=True)
        (d / "input.txt").write_text(f"{len(arr)}\n{' '.join(map(str, arr))}\n", encoding="utf-8")
        (d / "output.txt").write_text(" ".join(map(str, output)) + "\n", encoding="utf-8")
        (d / "answer.txt").write_text(f"{answer[0]} {answer[1]}\n", encoding="utf-8")
        (d / "verdict").write_text(verdict + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--seed", default="cs2026-warmups-v1")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    make_numbers(out, random.Random(args.seed + ":numbers"))
    make_text(out, random.Random(args.seed + ":text"))
    make_tree(out, random.Random(args.seed + ":tree"))
    make_files(out, random.Random(args.seed + ":files"))
    make_checker_cases(out, random.Random(args.seed + ":checker"))
    print(f"Готово: {out}/ (numbers.txt, text.txt, tree/, files/, checker-cases/)")


if __name__ == "__main__":
    main()
