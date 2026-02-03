---
title: "Algorithm Test"
author: "Test Author"
---

# Algorithms

::: {.algorithm #alg-sort title="QuickSort"}
```algorithm
function QuickSort(A, lo, hi)
  if lo < hi then
    p ← Partition(A, lo, hi)
    QuickSort(A, lo, p-1)
    QuickSort(A, p+1, hi)
  end if
end function
```
:::
