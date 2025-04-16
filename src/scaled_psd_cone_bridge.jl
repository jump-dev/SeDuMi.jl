# Copyright (c) 2017: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

struct ScaledPSDCone <: MOI.AbstractVectorSet
    side_dimension::Int
end

Base.copy(x::ScaledPSDCone) = ScaledPSDCone(x.side_dimension)

MOI.side_dimension(x::ScaledPSDCone) = x.side_dimension

function MOI.dimension(x::ScaledPSDCone)
    return x.side_dimension^2
end

function MOI.Utilities.set_with_dimension(::Type{ScaledPSDCone}, dim)
    return ScaledPSDCone(isqrt(dim))
end

struct ScaledPSDConeBridge{T,G} <: MOI.Bridges.Constraint.SetMapBridge{
    T,
    ScaledPSDCone,
    MOI.PositiveSemidefiniteConeTriangle,
    MOI.VectorAffineFunction{T},
    G,
}
    constraint::MOI.ConstraintIndex{MOI.VectorAffineFunction{T},ScaledPSDCone}
end

function MOI.Bridges.Constraint.concrete_bridge_type(
    ::Type{ScaledPSDConeBridge{T}},
    ::Type{G},
    ::Type{MOI.PositiveSemidefiniteConeTriangle},
) where {T,G<:Union{MOI.VectorOfVariables,MOI.VectorAffineFunction{T}}}
    return ScaledPSDConeBridge{T,G}
end

function MOI.Bridges.map_set(
    ::Type{<:ScaledPSDConeBridge},
    set::MOI.PositiveSemidefiniteConeTriangle,
)
    return ScaledPSDCone(set.side_dimension)
end

function MOI.Bridges.inverse_map_set(
    ::Type{<:ScaledPSDConeBridge},
    set::ScaledPSDCone,
)
    return MOI.PositiveSemidefiniteConeTriangle(set.side_dimension)
end

# Map ConstraintFunction from MOI -> SeDuMi
function MOI.Bridges.map_function(
    BT::Type{<:ScaledPSDConeBridge{T}},
    func::MOI.VectorOfVariables,
) where {T}
    new_f = MOI.Utilities.operate(*, Float64, 1.0, func)
    return MOI.Bridges.map_function(BT, new_f)
end
function MOI.Bridges.map_function(
    ::Type{<:ScaledPSDConeBridge},
    f::MOI.VectorAffineFunction,
)
    n = MOI.output_dimension(f)
    d = MOI.Utilities.side_dimension_for_vectorized_dimension(n)
    constants = copy(f.constants)
    scale_coefficients!(constants)
    constants = triangle_to_square(constants, d)
    terms = copy(f.terms)
    scale_coefficients!(terms)
    triangle_to_square_indices!(terms, d)
    return MOI.VectorAffineFunction(terms, constants)
end

# Used to map the ConstraintPrimal from SeDuMi -> MOI
function MOI.Bridges.inverse_map_function(::Type{<:ScaledPSDConeBridge}, square)
    triangle = square_to_triangle(square)
    unscale_coefficients!(triangle)
    return triangle
end

# Used to map the ConstraintDual from SeDuMi -> MOI
function MOI.Bridges.adjoint_map_function(::Type{<:ScaledPSDConeBridge}, square)
    triangle = square_to_triangle(square)
    n = isqrt(length(square))
    for i in 1:n, j in 1:(i-1)
        # Add lower diagonal dual. It should be equal to upper diagonal dual
        # but `unscale_coefficients` will divide by 2 so it will do the mean
        triangle[MOI.Utilities.trimap(i, j)] += square[square_map(i, j, n)]
    end
    unscale_coefficients!(triangle)
    return triangle
end

# `dimension` -> `side_dimension`, see
# http://jump.dev/MathOptInterface.jl/v0.8.1/apireference/#MathOptInterface.PositiveSemidefiniteConeTriangle
triangle_side_dimension(n) = div(isqrt(1 + 8n) - 1, 2)
square_side_dimension(n) = isqrt(n)

function square_map(i::Integer, j::Integer, n::Integer)
    if i < j
        return square_map(j, i, n)
    else
        return i + (j - 1) * n
    end
end

function copy_upper_triangle(x, n, map_from, map_to)
    y = zeros(eltype(x), map_to(n, n))
    for i in 1:n, j in 1:i
        y[map_to(i, j)] = x[map_from(i, j)]
    end
    return y
end
function square_to_triangle(x, n = square_side_dimension(length(x)))
    return copy_upper_triangle(
        x,
        n,
        (i, j) -> square_map(i, j, n),
        MOI.Utilities.trimap,
    )
end
function triangle_to_square(x, n = triangle_side_dimension(length(x)))
    return copy_upper_triangle(
        x,
        n,
        MOI.Utilities.trimap,
        (i, j) -> square_map(i, j, n),
    )
end

function triangle_to_square_indices!(x::Vector{<:MOI.VectorAffineTerm}, n)
    map = square_to_triangle(1:n^2, n)
    for i in eachindex(x)
        x[i] = MOI.VectorAffineTerm(map[x[i].output_index], x[i].scalar_term)
    end
end

_row(i, t::MOI.VectorAffineTerm) = t.output_index
_row(i, β) = i

_prod(α, t::MOI.VectorAffineTerm) = MOI.Utilities.operate_term(*, α, t)
_prod(α, β) = α * β

# Scale coefficients depending on rows index on symmetric packed upper triangular form
# coef: List of coefficients
# rev: if true, we unscale instead (e.g. divide by √2 instead of multiply for PSD cone)
# rows: List of row indices
# d: dimension of set
function _scale_coefficients!(coef::AbstractVector, rev::Bool)
    scaling = rev ? 0.5 : 2.0
    for i in 1:length(coef)
        if !MOI.Utilities.is_diagonal_vectorized_index(_row(i, coef[i]))
            coef[i] = _prod(scaling, coef[i])
        end
    end
end
# Scale the coefficients in `coef` with respective rows in `rows` for a set `s`
function scale_coefficients!(coef)
    return _scale_coefficients!(coef, false)
end
# Unscale the coefficients of `coef` in symmetric packed upper triangular form
function unscale_coefficients!(coef)
    return _scale_coefficients!(coef, true)
end
