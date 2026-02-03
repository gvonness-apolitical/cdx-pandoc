---
title: "Academic Kitchen Sink"
author: "Test Author"
date: "2024-01-15"
---

::: {.abstract}
This document tests all academic block types interacting together,
including theorems, proofs, exercises, algorithms, and cross-references.

::: {.keywords}
mathematics, testing, academic blocks
:::
:::

# Theorems and Proofs

::: {.theorem #thm-fund title="Fundamental Theorem"}
Every continuous function on a closed interval $[a,b]$ attains its maximum.
:::

::: {.proof of="thm-fund" method="contradiction"}
Suppose $f$ does not attain its maximum. Then for every $x \in [a,b]$,
there exists $y$ with $f(y) > f(x)$. This contradicts compactness.
:::

::: {.lemma #lem-helper}
If $f$ is continuous on $[a,b]$, then $f$ is bounded.
:::

::: {.definition #def-compact title="Compactness"}
A set $K$ is compact if every open cover has a finite subcover.
:::

By [Theorem 1](#thm-fund) and [Lemma 1](#lem-helper), the result follows.

# Exercises

::: {.exercise #ex-calc difficulty="easy"}
Compute the derivative of $f(x) = x^3 - 2x + 1$.

::: {.hint}
Use the power rule: $\frac{d}{dx}x^n = nx^{n-1}$.
:::

::: {.solution visibility="hidden"}
$f'(x) = 3x^2 - 2$
:::
:::

# Algorithms

::: {.algorithm #alg-binary title="Binary Search"}
```algorithm
function BinarySearch(A, target, lo, hi)
  if lo > hi then
    return NOT_FOUND
  end if
  mid ← (lo + hi) / 2
  if A[mid] = target then
    return mid
  else if A[mid] < target then
    return BinarySearch(A, target, mid+1, hi)
  else
    return BinarySearch(A, target, lo, mid-1)
  end if
end function
```
:::

See [Algorithm 1](#alg-binary) for the implementation.

# Equation Groups

$$\begin{align}
\nabla \cdot \mathbf{E} &= \frac{\rho}{\epsilon_0} \\
\nabla \cdot \mathbf{B} &= 0 \\
\nabla \times \mathbf{E} &= -\frac{\partial \mathbf{B}}{\partial t}
\end{align}$$

See [Equation (1)](#eq-maxwell) for Maxwell's equations.

# Admonitions

::: {.warning title="Convergence"}
The series may not converge for all values of $x$.
:::

::: {.tip}
Use the ratio test to check convergence.
:::
