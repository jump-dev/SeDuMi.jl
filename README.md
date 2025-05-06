# SeDuMi.jl

[SeDuMi.jl](https://github.com/jump-dev/SeDuMi.jl) is wrapper for the [SeDuMi](http://sedumi.ie.lehigh.edu/) solver.

The wrapper has two components:
 * an exported `sedumi` function that is a thin wrapper on top of the `sedumi`
   MATLAB function
 * an interface to [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl)

Note that this SeDuMi natively supports the [Hermitian PSD cone](https://jump.dev/JuMP.jl/stable/manual/variables/#Example:-Hermitian-positive-semidefinite-variables).
This interface provides the support of conic constraints, as create with
`@constraint(model, ... in PSDCone())` or
`@constraint(model, ... in HermitianPSDCone())`.
If your model rather contains conic variables such as created with
`@variable(model, ... in PSDCone())` or
`@variable(model, ... in HermitianPSDCone())`, you should try
[adding a Dualization layer](https://jump.dev/JuMP.jl/stable/tutorials/conic/dualization/)
to see if it improves the solve time.

## Affiliation

This wrapper is maintained by the JuMP community and is not an official wrapper
of SeDuMi.

## License

`SeDuMi.jl` is licensed under the [MIT License](https://github.com/jump-dev/SeDuMi.jl/blob/master/LICENSE.md).

The underlying solver, [sqlp/sedumi](https://github.com/sqlp/sedumi) is licensed
under the [GPL v2 license](https://github.com/sqlp/sedumi/blob/master/COPYING).

In addition, SeDuMi requires an installation of MATLAB, which is a closed-source
commercial product for which you must [obtain a license](https://www.mathworks.com/products/matlab.html).

## Use with JuMP

To use SeDuMi with [JuMP](https://github.com/jump-dev/JuMP.jl), do:
```julia
using JuMP, SeDuMi
model = Model(SeDuMi.Optimizer)
set_attribute(model, "fid", 0)
```

## MathOptInterface API

The SeDuMi optimizer supports the following constraints and attributes.

List of supported objective functions:

 * [`MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}`](@ref)

List of supported variable types:

 * [`MOI.Reals`](@ref)

List of supported constraint types:

 * [`MOI.VectorAffineFunction{Float64}`](@ref) in [`MOI.Nonnegatives`](@ref)
 * [`MOI.VectorAffineFunction{Float64}`](@ref) in [`MOI.RotatedSecondOrderCone`](@ref)
 * [`MOI.VectorAffineFunction{Float64}`](@ref) in [`MOI.SecondOrderCone`](@ref)
 * [`MOI.VectorAffineFunction{Float64}`](@ref) in [`MOI.Zeros`](@ref)
 * [`MOI.VectorAffineFunction{Float64}`](@ref) in `SeDuMi.ScaledPSDCone`
 * [`MOI.VectorAffineFunction{ComplexF64}`](@ref) in `SeDuMi.ScaledPSDCone`

List of supported model attributes:

 * [`MOI.ObjectiveSense()`](@ref)

## Installation

First, make sure that you satisfy the requirements of the
[MATLAB.jl](https://github.com/JuliaInterop/MATLAB.jl) Julia package, and that
the SeDuMi software is installed in your
[MATLAB™](http://www.mathworks.com/products/matlab/) installation.

Then, install `SeDuMi.jl` using `Pkg.add`:
```julia
import Pkg
Pkg.add("SeDuMi")
```

If you get the error:
```raw
Undefined function or variable 'sedumi'.

Error using save
Variable 'jx_sedumi_arg_out_1' not found.

ERROR: LoadError: MATLAB.MEngineError("failed to get variable jx_sedumi_arg_out_1 from MATLAB session")
```
The error means that we couldn't find the `sedumi` function with one output
argument using the MATLAB C API.

This most likely means that you did not add SeDuMi to the MATLAB's path, that
is, the `toolbox/local/pathdef.m` file.

If modifying `toolbox/local/pathdef.m` does not work, the following should work,
where `/path/to/sedumi/` is the directory where the `sedumi` folder is located:
```julia
julia> import MATLAB

julia> cd("/path/to/sedumi/") do
           MATLAB.mat"install_sedumi"
       end

julia> MATLAB.mat"savepath"
```
