# Copyright (c) 2017: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module SeDuMi

using SparseArrays
using MATLAB

export sedumi

# The fields should be integer values but the type should be `Float64` to work
# with SeDuMi
mutable struct Cone
    f::Float64 # number of free primal variables / linear dual equality constraints
    l::Float64 # length of LP cone
    q::Vector{Float64} # list of second-order cone dimensions
    r::Vector{Float64} # list of rotated second-order cone dimensions
    s::Vector{Float64} # list of semidefinite cone dimensions
    scomplex::Vector{Float64} #list of semidefinite cones that are Hermitian PSD instead of Symmetric PSD
    ycomplex::Vector{Float64} #list of constraints on A*x that should also act on the imaginary part
    xcomplex::Vector{Float64} #list of components of f,l,q,r blocks allowed to be complex
end

function Cone(
    f::Real,
    l::Real,
    q::Vector = Float64[],
    r::Vector = Float64[],
    s::Vector = Float64[],
    scomplex::Vector = Float64[],
)
    return Cone(f, l, q, r, s, scomplex, Float64[], Float64[])
end

dimension(K::Cone) = K.f + K.l + sum(K.q) + sum(K.r) + sum(K.s .^ 2)

to_vec(x::Vector) = x
to_vec(x::Float64) = [x]
to_vec(x::ComplexF64) = [x]
function to_vec(x::AbstractMatrix)
    @assert isempty(x) || isone(size(x, 2))
    return vec(x)
end

# Solve the primal/dual pair
# min c'x,      max b'y
# s.t. Ax = b,   c - A'y ∈ K
#       x ∈ K
#
# Note, if `A` is square then SeDuMi assumes that `A'` is passed instead,
# see https://github.com/sqlp/sedumi/issues/42
function sedumi(
    A::Union{
        Matrix{Float64},
        SparseMatrixCSC{Float64},
        Matrix{ComplexF64},
        SparseMatrixCSC{ComplexF64},
    },
    b::Union{Vector{Float64},Vector{ComplexF64}},
    c::Union{Vector{Float64},Vector{ComplexF64}},
    K::Cone = Cone(0, size(A, 2));
    kws...,
)
    pars = Dict{String,Any}(string(key) => value for (key, value) in kws)
    @assert size(A, 1) == length(b)
    @assert size(A, 2) == length(c)
    @assert size(A, 2) == dimension(K)
    # There are 3 output arguments: x, y and info so we use `3` above
    x, y, info = mxcall(:sedumi, 3, A, b, c, K, pars)
    return to_vec(x), to_vec(y), info
end

include("MOI_wrapper.jl")

end # module
