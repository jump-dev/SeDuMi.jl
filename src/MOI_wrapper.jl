using MathOptInterface
const MOI = MathOptInterface

include("scaled_psd_cone_bridge.jl")
include("scaled_hermitian_psd_cone_bridge.jl")

import LinearAlgebra

# SeDuMi solves the primal/dual pair
# min c'x,       max b'y
# s.t. Ax = b,   c - A'x ∈ K
#       x ∈ K
# where K is a product of `MOI.Zeros`, `MOI.Nonnegatives`,
# `MOI.SecondOrderCone`, `MOI.RotatedSecondOrderCone` and
# `SeDuMi.ScaledPSDCone`.

# This wrapper copies the MOI problem to the SeDuMi dual so the natively
# supported supported sets are `VectorAffineFunction`-in-`S` where `S` is one
# of the sets just listed above.

const ComplexAff = MOI.VectorAffineFunction{Complex{Float64}}
const RealAff = MOI.VectorAffineFunction{Float64}

MOI.Utilities.@struct_of_constraints_by_function_types(
    ComplexOrReal,
    ComplexAff,
    RealAff,
)

MOI.Utilities.@product_of_sets(
    ComplexCones,
    MOI.HermitianPositiveSemidefiniteConeTriangle,
)

MOI.Utilities.@product_of_sets(
    Cones,
    MOI.Zeros,
    MOI.Nonnegatives,
    MOI.SecondOrderCone,
    MOI.RotatedSecondOrderCone,
    ScaledPSDCone,
)

const OptimizerCache = MOI.Utilities.GenericModel{
    Float64,
    MOI.Utilities.ObjectiveContainer{Float64},
    MOI.Utilities.VariablesContainer{Float64},
    ComplexOrReal{Float64}{
        MOI.Utilities.MatrixOfConstraints{
            Float64,
            MOI.Utilities.MutableSparseMatrixCSC{
                Float64,
                Int,
                MOI.Utilities.OneBasedIndexing,
            },
            Vector{Float64},
            ComplexCones{Float64},
        },
        MOI.Utilities.MatrixOfConstraints{
            Float64,
            MOI.Utilities.MutableSparseMatrixCSC{
                Float64,
                Int,
                MOI.Utilities.OneBasedIndexing,
            },
            Vector{Float64},
            Cones{Float64},
        },
    },
}

mutable struct Solution
    x::Vector{Float64}
    y::Vector{Float64}
    slack::Vector{Float64}
    objective_value::Float64
    dual_objective_value::Float64
    objective_constant::Float64
    info::Dict{String,Any}
end

mutable struct Optimizer <: MOI.AbstractOptimizer
    cones::Union{Nothing,Cones{Float64}}
    sol::Union{Nothing,Solution}
    silent::Bool
    options::Dict{Symbol,Any}
    function Optimizer()
        return new(nothing, nothing, false, Dict{Symbol,Any}())
    end
end

function MOI.default_cache(::Optimizer, ::Type{Float64})
    return MOI.Utilities.UniversalFallback(OptimizerCache())
end

function MOI.get(::Optimizer, ::MOI.Bridges.ListOfNonstandardBridges)
    return [ScaledPSDConeBridge{Float64}, ScaledHermitianPSDConeBridge{Float64}]
end

MOI.get(::Optimizer, ::MOI.SolverName) = "SeDuMi"

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.cones === nothing
end
function MOI.empty!(optimizer::Optimizer)
    optimizer.cones = nothing
    optimizer.sol = nothing
    return
end

###
### MOI.RawOptimizerAttribute
###

function MOI.set(optimizer::Optimizer, param::MOI.RawOptimizerAttribute, value)
    optimizer.options[Symbol(param.name)] = value
    return
end

function MOI.get(optimizer::Optimizer, param::MOI.RawOptimizerAttribute)
    return optimizer.options[Symbol(param.name)]
end

###
### MOI.Silent
###

MOI.supports(::Optimizer, ::MOI.Silent) = true

function MOI.set(optimizer::Optimizer, ::MOI.Silent, value::Bool)
    return optimizer.silent = value
end

MOI.get(optimizer::Optimizer, ::MOI.Silent) = optimizer.silent

###
### MOI.AbstractModelAttribute
###

function MOI.supports(
    ::Optimizer,
    ::Union{
        MOI.ObjectiveSense,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}},
    },
)
    return true
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorAffineFunction{Float64}},
    ::Type{
        <:Union{
            MOI.Zeros,
            MOI.Nonnegatives,
            MOI.SecondOrderCone,
            MOI.RotatedSecondOrderCone,
            ScaledPSDCone,
        },
    },
)
    return true
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{MOI.VectorAffineFunction{ComplexF64}},
    ::Type{ScaledPSDCone},
)
    return true
end

function _map_sets(f, sets, ::Type{S}) where {S}
    F = MOI.VectorAffineFunction{Float64}
    cis = MOI.get(sets, MOI.ListOfConstraintIndices{F,S}())
    return Int[f(MOI.get(sets, MOI.ConstraintSet(), ci)) for ci in cis]
end

function MOI.optimize!(dest::Optimizer, src::OptimizerCache)
    MOI.empty!(dest)
    index_map = MOI.Utilities.identity_index_map(src)
    Ac = src.constraints
    A = Ac.coefficients

    model_attributes = MOI.get(src, MOI.ListOfModelAttributesSet())
    objective_function_attr =
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}()
    b = zeros(A.n)
    max_sense = MOI.get(src, MOI.ObjectiveSense()) == MOI.MAX_SENSE
    objective_constant = 0.0
    if objective_function_attr in MOI.get(src, MOI.ListOfModelAttributesSet())
        obj = MOI.get(src, objective_function_attr)
        objective_constant = MOI.constant(obj)
        for term in obj.terms
            b[term.variable.value] += (max_sense ? 1 : -1) * term.coefficient
        end
    end

    # If m == n, SeDuMi thinks we give A'.
    # See https://github.com/sqlp/sedumi/issues/42#issuecomment-451300096
    A = SparseMatrixCSC(A.m, A.n, A.colptr, A.rowval, -A.nzval)
    if A.m != A.n
        A = SparseMatrixCSC(A')
    end

    options = dest.options
    if dest.silent
        options = copy(options)
        options[:fid] = 0
    end

    K = Cone(
        Ac.sets.num_rows[1],
        Ac.sets.num_rows[2] - Ac.sets.num_rows[1],
        _map_sets(MOI.dimension, Ac, MOI.SecondOrderCone),
        _map_sets(MOI.dimension, Ac, MOI.RotatedSecondOrderCone),
        _map_sets(MOI.side_dimension, Ac, ScaledPSDCone),
    )

    c = Ac.constants
    x, y, info = sedumi(A, b, c, K; options...)

    dest.cones = deepcopy(Ac.sets)
    objective_value = (max_sense ? 1 : -1) * LinearAlgebra.dot(b, y)
    dual_objective_value = (max_sense ? 1 : -1) * LinearAlgebra.dot(c, x)
    dest.sol = Solution(
        x,
        y,
        c - A' * y,
        objective_value,
        dual_objective_value,
        objective_constant,
        info,
    )
    return index_map, false
end

function MOI.optimize!(
    dest::Optimizer,
    src::MOI.Utilities.UniversalFallback{OptimizerCache},
)
    MOI.Utilities.throw_unsupported(src)
    return MOI.optimize!(dest, src.model)
end

function MOI.optimize!(dest::Optimizer, src::MOI.ModelLike)
    cache = OptimizerCache()
    index_map = MOI.copy_to(cache, src)
    MOI.optimize!(dest, cache)
    return index_map, false
end

function MOI.get(optimizer::Optimizer, ::MOI.SolveTimeSec)
    return optimizer.sol.info["cpusec"]
end
function MOI.get(optimizer::Optimizer, ::MOI.RawStatusString)
    return string(
        "feasratio = ",
        optimizer.sol.info["feasratio"],
        ", pinf = ",
        optimizer.sol.info["pinf"],
        ", dinf = ",
        optimizer.sol.info["dinf"],
        "numerr = ",
        optimizer.sol.info["numerr"],
    )
end

# Implements getter for result value and statuses
# SeDuMI returns one of the following values (based on SeDuMi_Guide_11 by Pólik):
# feasratio:  1.0 problem with complementary solution
#            -1.0 strongly infeasible problem
#             between -1.0 and 1.0 nasty problem
# pinf = 1.0 : y is infeasibility certificate => SeDuMi primal/MOI dual is infeasible
# dinf = 1.0 : x is infeasibility certificate => SeDuMi dual/MOI primal is infeasible
# pinf = 0.0 = dinf : x and y are near feasible
# numerr: 0 desired accuracy (specified by pars.eps) is achieved
#         1 reduced accuracy (specified by pars.bigeps) is achieved
#         2 failure due to numerical problems

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    if optimizer.sol isa Nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    pinf = optimizer.sol.info["pinf"]
    dinf = optimizer.sol.info["dinf"]
    numerr = optimizer.sol.info["numerr"]
    if numerr == 2
        return MOI.NUMERICAL_ERROR
    end
    @assert iszero(numerr) || isone(numerr)
    accurate = iszero(numerr)
    if isone(pinf)
        if accurate
            return MOI.DUAL_INFEASIBLE
        else
            return MOI.ALMOST_DUAL_INFEASIBLE
        end
    end
    if isone(dinf)
        if accurate
            return MOI.INFEASIBLE
        else
            return MOI.ALMOST_INFEASIBLE
        end
    end
    @assert iszero(pinf) && iszero(dinf)
    # TODO when do we return SLOW_PROGRESS ?
    #      Maybe we should use feasratio
    if accurate
        return MOI.OPTIMAL
    else
        return MOI.ALMOST_OPTIMAL
    end
end

function MOI.get(optimizer::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(optimizer, attr)
    value = optimizer.sol.objective_value
    if !MOI.Utilities.is_ray(MOI.get(optimizer, MOI.PrimalStatus()))
        value += optimizer.sol.objective_constant
    end
    return value
end
function MOI.get(optimizer::Optimizer, attr::MOI.DualObjectiveValue)
    MOI.check_result_index_bounds(optimizer, attr)
    value = optimizer.sol.dual_objective_value
    if !MOI.Utilities.is_ray(MOI.get(optimizer, MOI.DualStatus()))
        value += optimizer.sol.objective_constant
    end
    return value
end

function MOI.get(
    optimizer::Optimizer,
    attr::Union{MOI.PrimalStatus,MOI.DualStatus},
)
    if attr.result_index > MOI.get(optimizer, MOI.ResultCount()) ||
       optimizer.sol isa Nothing
        return MOI.NO_SOLUTION
    end
    pinf = optimizer.sol.info["pinf"]
    dinf = optimizer.sol.info["dinf"]
    numerr = optimizer.sol.info["numerr"]
    if numerr == 2
        return MOI.UNKNOWN_RESULT_STATUS
    end
    @assert iszero(numerr) || isone(numerr)
    accurate = iszero(numerr)
    if isone(attr isa MOI.PrimalStatus ? pinf : dinf)
        if accurate
            return MOI.INFEASIBILITY_CERTIFICATE
        else
            return MOI.NEARLY_INFEASIBILITY_CERTIFICATE
        end
    end
    if isone(attr isa MOI.PrimalStatus ? dinf : pinf)
        return MOI.INFEASIBLE_POINT
    end
    @assert iszero(pinf) && iszero(dinf)
    if accurate
        return MOI.FEASIBLE_POINT
    else
        return MOI.NEARLY_FEASIBLE_POINT
    end
end
function MOI.get(
    optimizer::Optimizer,
    attr::MOI.VariablePrimal,
    vi::MOI.VariableIndex,
)
    MOI.check_result_index_bounds(optimizer, attr)
    return optimizer.sol.y[vi.value]
end
function MOI.get(
    optimizer::Optimizer,
    attr::MOI.ConstraintPrimal,
    ci::MOI.ConstraintIndex,
)
    MOI.check_result_index_bounds(optimizer, attr)
    return optimizer.sol.slack[MOI.Utilities.rows(optimizer.cones, ci)]
end

function MOI.get(
    optimizer::Optimizer,
    attr::MOI.ConstraintDual,
    ci::MOI.ConstraintIndex,
)
    MOI.check_result_index_bounds(optimizer, attr)
    return optimizer.sol.x[MOI.Utilities.rows(optimizer.cones, ci)]
end

MOI.get(optimizer::Optimizer, ::MOI.ResultCount) = 1
