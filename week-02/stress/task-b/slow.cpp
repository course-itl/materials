// slow.cpp — «тупое» решение задачи B «Отрезок максимальной суммы», O(n^2).
// Перебираем все отрезки; из отрезков с максимальной суммой выводим тот,
// что встретился ПОСЛЕДНИМ в порядке перебора (l по возрастанию, затем r).
// Это законно: условие разрешает вывести любой.
#include <iostream>
#include <vector>

int main() {
    std::ios::sync_with_stdio(false);
    int n;
    if (!(std::cin >> n)) return 1;
    std::vector<long long> a(n);
    for (auto& x : a) std::cin >> x;

    long long best = a[0];
    int bl = 0, br = 0;
    for (int l = 0; l < n; l++) {
        long long s = 0;
        for (int r = l; r < n; r++) {
            s += a[r];
            if (s >= best) { best = s; bl = l; br = r; }
        }
    }
    std::cout << bl + 1 << " " << br + 1 << "\n";
    return 0;
}
