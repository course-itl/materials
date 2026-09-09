// slow.cpp — «тупое» решение задачи A «Сумма максимумов».
// O(n^2): перебираем все подотрезки, максимум поддерживаем по ходу.
// Правильность очевидна из условия — это и есть его ценность. На n ≤ 5000
// работает мгновенно, на n = 2·10^5 — нет; для стресс-теста этого достаточно.
#include <iostream>
#include <vector>

int main() {
    std::ios::sync_with_stdio(false);
    int n;
    if (!(std::cin >> n)) return 1;
    std::vector<long long> a(n);
    for (auto& x : a) std::cin >> x;

    long long ans = 0;
    for (int l = 0; l < n; l++) {
        long long mx = a[l];
        for (int r = l; r < n; r++) {
            if (a[r] > mx) mx = a[r];
            ans += mx;
        }
    }
    std::cout << ans << "\n";
    return 0;
}
