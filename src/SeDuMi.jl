module SeDuMi

using MATLAB

export sedumi

# Solve the LP in standard form: min c'x, s.t. Ax = b, x ≥ 0
function sedumi(A::Matrix{Float64}, b::Vector{Float64}, c::Vector{Float64})
    return mxcall(:sedumi, 3, A, b, c)
end

end # module
