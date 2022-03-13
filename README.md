# SeDuMi

`SeDuMi.jl` is an interface to the **[SeDuMi](http://sedumi.ie.lehigh.edu/)**
solver. It exports the `sedumi` function that is a thin wrapper on top of the
`sedumi` MATLAB function and uses it to define the `SeDuMi.Optimizer` object
that implements the solver-independent
[MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl) API.

To use it with [JuMP](https://github.com/jump-dev/JuMP.jl), simply do
```julia
using JuMP
using SeDuMi
model = Model(SeDuMi.Optimizer)
```
To suppress output, do
```julia
model = Model(optimizer_with_attributes(SeDuMi.Optimizer, fid=0))
```

## Installation

You can install `SeDuMi.jl` through the
[Julia package manager](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html):
```julia
] add SeDuMi
```
but you first need to make sure that you satisfy the requirements of the
[MATLAB.jl](https://github.com/JuliaInterop/MATLAB.jl) Julia package and that
the SeDuMi software is installed in your
[MATLAB™](http://www.mathworks.com/products/matlab/) installation.

### Troubleshooting

#### SeDuMi not in PATH

If you get the error:
```
Undefined function or variable 'sedumi'.

Error using save
Variable 'jx_sedumi_arg_out_1' not found.

ERROR: LoadError: MATLAB.MEngineError("failed to get variable jx_sedumi_arg_out_1 from MATLAB session")
```
The error means that we try to find the `sedumi` function with 1 output argument using the MATLAB C API but it wasn't found.
This most likely means that you did not add SeDuMi to the MATLAB's path (i.e. the `toolbox/local/pathdef.m` file).

If modifying `toolbox/local/pathdef.m` does not work, the following should work where `/path/to/sedumi/` is the directory where the `sedumi` folder is located:
```julia
julia> using MATLAB

julia> cd("/path/to/sedumi/") do
           mat"install_sedumi"
       end
```
This should make `SeDuMi.jl` work for the Julia session in which this is run.
Alternatively, run
```julia
julia> mat"savepath"
```
to make `SeDuMi.jl` work for future Julia sessions.
