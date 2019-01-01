# SeDuMi

`SeDuMi.jl` is an interface to the **[SeDuMi](http://sedumi.ie.lehigh.edu/)** solver.
It is still a work in progress but it aims to provide a complete interface to the low-level MATLAB API,
as well as an implementation of the solver-independent `MathOptInterface` API.

## Installation

You can install `SeDuMi.jl` through the Julia package manager:
```julia
] add SeDuMi
```
but you first need to make sure that you satisfy the requirements of the
[MATLAB.jl](https://github.com/JuliaInterop/MATLAB.jl) Julia package and that
the SeDuMi software is installed in your
[MATLAB™](http://www.mathworks.com/products/matlab/) installation.
