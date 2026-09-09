// fast.cpp — «быстрое» решение задачи B «Отрезок максимальной суммы», O(n).
// Алгоритм Кадане: тянем текущий отрезок, пока его сумма не стала
// отрицательной, — тогда выгоднее начать заново со следующего элемента.
// Ответ — лучший из текущих отрезков за весь проход.
//
// Где-то здесь баг. Учтите: ответ в задаче не единственный, поэтому
// «выводы различаются» — ещё не приговор. Нужен чекер.
#include <iostream>
#include <vector>

int main() {
    std::ios::sync_with_stdio(false);
    int n;
    if (!(std::cin >> n)) return 1;
    std::vector<long long> a(n);
    for (auto& x : a) std::cin >> x;

    long long best = 0, cur = 0;
    int bl = 0, br = 0, curl = 0;
    for (int i = 0; i < n; i++) {
        cur += a[i];
        if (cur > best) { best = cur; bl = curl; br = i; }
        if (cur < 0) { cur = 0; curl = i + 1; }
    }
    std::cout << bl + 1 << " " << br + 1 << "\n";
    return 0;
}
