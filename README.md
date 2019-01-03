# SeDuMi

`SeDuMi.jl` is an interface to the **[SeDuMi](http://sedumi.ie.lehigh.edu/)**
solver. It exports the `sedumi` function that is a thin wrapper on top of the
`sedumi` MATLAB function and use it to define the `SeDuMi.Optimizer` object that
implements the solver-independent `MathOptInterface` API.

To use it with JuMP, simply do
```julia
using JuMP
using SeDuMi
model = Model(with_optimizer(SeDuMi.Optimizer))
```
To suppress output, do
```julia
model = Model(with_optimizer(SeDuMi.Optimizer, fid=0))
```

## Installation

You can install `SeDuMi.jl` through the Julia package manager:
```julia
] add https://github.com/blegat/SeDuMi.jl.git
```
but you first need to make sure that you satisfy the requirements of the
[MATLAB.jl](https://github.com/JuliaInterop/MATLAB.jl) Julia package and that
the SeDuMi software is installed in your
[MATLAB™](http://www.mathworks.com/products/matlab/) installation.
