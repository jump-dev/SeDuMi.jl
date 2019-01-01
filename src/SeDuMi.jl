module SeDuMi

using SparseArrays
using MATLAB

export sedumi

struct Cone
    f::Float64 # number of free primal variables / linear dual equality constraints
    l::Float64 # length of LP cone
    q::Vector{Float64} # list of second-order cone dimension
    r::Vector{Float64} # list of rotated second-order cone dimension
    s::Vector{Float64} # list of semidefinite constraints
end

# Solve the primal/dual pair
# min c'x,      max b'y
# s.t. Ax = b,   c - Ax ∈ K
#       x ∈ K
function sedumi(A::Union{Matrix{Float64}, SparseMatrixCSC{Float64}},
                b::Vector{Float64}, c::Vector{Float64},
                K::Cone = Cone(0, size(A, 2), Float64[], Float64[], Float64[]);
                kws...)
    pars = Dict{String, Any}(string(key) => value for (key, value) in kws)
    # There are 3 output arguments: x, y and info so we use `3` above
    return mxcall(:sedumi, 3, A, b, c, K, pars)
end

end # module
