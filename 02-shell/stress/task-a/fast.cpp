// fast.cpp — «быстрое» решение задачи A «Сумма максимумов», O(n).
// Метод вклада: каждый элемент a[i] является максимумом на всех отрезках,
// левый конец которых лежит в (L[i], i], а правый — в [i, R[i]), где
// L[i] — ближайший слева индекс с элементом больше a[i], R[i] — ближайший
// справа. Границы ищутся монотонным стеком.
//
// Решение проходит все тесты из условия, которые автор придумал руками.
// Где-то в нём баг. Не ищите его глазами — найдите стресс-тестом, потом
// объясните.
#include <iostream>
#include <vector>

int main() {
    std::ios::sync_with_stdio(false);
    int n;
    if (!(std::cin >> n)) return 1;
    std::vector<long long> a(n);
    for (auto& x : a) std::cin >> x;

    std::vector<int> L(n), R(n), st;
    st.reserve(n);

    for (int i = 0; i < n; i++) {
        while (!st.empty() && a[st.back()] <= a[i]) st.pop_back();
        L[i] = st.empty() ? -1 : st.back();
        st.push_back(i);
    }
    st.clear();
    for (int i = n - 1; i >= 0; i--) {
        while (!st.empty() && a[st.back()] <= a[i]) st.pop_back();
        R[i] = st.empty() ? n : st.back();
        st.push_back(i);
    }

    long long ans = 0;
    for (int i = 0; i < n; i++)
        ans += a[i] * (i - L[i]) * (R[i] - i);
    std::cout << ans << "\n";
    return 0;
}
