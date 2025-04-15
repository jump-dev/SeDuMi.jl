struct ScaledHermitianPSDConeBridge{T,G} <: MOI.Bridges.Constraint.SetMapBridge{
    T,
    ScaledPSDCone,
    MOI.HermitianPositiveSemidefiniteConeTriangle,
    MOI.VectorAffineFunction{ComplexF64},
    G,
}
    constraint::MOI.ConstraintIndex{
        MOI.VectorAffineFunction{ComplexF64},
        ScaledPSDCone,
    }
end

function MOI.Bridges.Constraint.concrete_bridge_type(
    ::Type{ScaledHermitianPSDConeBridge{T}},
    ::Type{G},
    ::Type{MOI.HermitianPositiveSemidefiniteConeTriangle},
) where {T,G<:Union{MOI.VectorOfVariables,MOI.VectorAffineFunction{T}}}
    return ScaledHermitianPSDConeBridge{T,G}
end

function MOI.Bridges.map_set(
    ::Type{<:ScaledHermitianPSDConeBridge},
    set::MOI.HermitianPositiveSemidefiniteConeTriangle,
)
    return ScaledPSDCone(set.side_dimension)
end

function MOI.Bridges.inverse_map_set(
    ::Type{<:ScaledHermitianPSDConeBridge},
    set::ScaledPSDCone,
)
    return MOI.HermitianPositiveSemidefiniteConeTriangle(set.side_dimension)
end

# Map ConstraintFunction from MOI -> SeDuMi
function MOI.Bridges.map_function(
    BT::Type{<:ScaledHermitianPSDConeBridge{T}},
    func::MOI.VectorOfVariables,
) where {T}
    new_f = MOI.Utilities.operate(*, Float64, 1.0, func)
    return MOI.Bridges.map_function(BT, new_f)
end
function MOI.Bridges.map_function(
    ::Type{<:ScaledHermitianPSDConeBridge},
    f::MOI.VectorAffineFunction,
)
    n = MOI.output_dimension(f)
    d = isqrt(n) #side dimension of Hermitian matrix
    constants = copy(f.constants)
    constants = hermitian_to_complex_triangle(constants, d)
    scale_coefficients!(constants)
    constants = triangle_to_square(constants, d)
    terms = copy(f.terms)
    terms = hermitian_to_complex_triangle_indices(terms, d)
    scale_coefficients!(terms)
    triangle_to_square_indices!(terms, d)
    return MOI.VectorAffineFunction(terms, constants)
end

# Used to map the ConstraintPrimal from SeDuMi -> MOI
function MOI.Bridges.inverse_map_function(
    ::Type{<:ScaledHermitianPSDConeBridge},
    square,
)
    return _sedumi_to_moi(square)
end

# Used to map the ConstraintDual from SeDuMi -> MOI
function MOI.Bridges.adjoint_map_function(
    ::Type{<:ScaledHermitianPSDConeBridge},
    square,
)
    return _sedumi_to_moi(square)
end

function _sedumi_to_moi(square)
    n = isqrt(length(square))
    triangle_size = div(n * (n + 1), 2)
    triangle = Vector{real(eltype(square))}(undef, n^2)
    for j in 1:n, i in 1:j
        triangle[MOI.Utilities.trimap(i, j)] = real(square[square_map(i, j, n)])
    end
    counter = 0
    for j in 2:n, i in 1:j-1
        counter += 1
        triangle[triangle_size+counter] = imag(square[square_map(i, j, n)])
    end
    return triangle
end

function hermitian_to_complex_triangle(x, n)
    triangle_size = div(n * (n + 1), 2)
    y = ComplexF64.(x[1:triangle_size])
    for i in 1:n-1, j in i+1:n
        y[MOI.Utilities.trimap(i, j)] +=
            im * x[triangle_size+MOI.Utilities.trimap(i, j - 1)]
    end
    return y
end

function hermitian_to_complex_triangle_indices(
    x::Vector{<:MOI.VectorAffineTerm},
    n,
)
    triangle_size = div(n * (n + 1), 2)
    map = zeros(Int64, div(n * (n - 1), 2))
    for i in 1:n-1, j in i+1:n
        map[MOI.Utilities.trimap(i, j - 1)] = MOI.Utilities.trimap(i, j)
    end
    x = convert(Vector{MOI.VectorAffineTerm{ComplexF64}}, x)
    for i in eachindex(x)
        if x[i].output_index >= triangle_size + 1
            x[i] = MOI.VectorAffineTerm(
                map[x[i].output_index-triangle_size],
                MOI.ScalarAffineTerm(
                    im * x[i].scalar_term.coefficient,
                    x[i].scalar_term.variable,
                ),
            )
        end
    end
    return x
end
