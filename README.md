# Latex

[![Build Status](https://travis-ci.org/rened/Latex.jl.svg?branch=master)](https://travis-ci.org/rened/Latex.jl)

This package allows to construct Latex documents programmatically.

```jl
x = linspace(-6,6,100)
y = sin(x)./x

import Winston
w = Image([], 7, Winston.plot(x, y))

import Gadfly
g = Image(7, 7, Gadfly.plot(x = x, y = y))

openpdf(report(Section("Plots",Figure("Plot comparison",Tabular({w,g})))))
```

![](example.png)
