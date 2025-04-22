module TestSeDuMi

using Test
using MathOptInterface
import SeDuMi

const MOI = MathOptInterface

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_solver_name()
    @test MOI.get(SeDuMi.Optimizer(), MOI.SolverName()) == "SeDuMi"
end

function test_options()
    optimizer = SeDuMi.Optimizer()
    MOI.set(optimizer, MOI.RawOptimizerAttribute("fid"), 0)
    @test MOI.get(optimizer, MOI.RawOptimizerAttribute("fid")) == 0
end

function test_complex()
    model = MOI.instantiate(SeDuMi.Optimizer; with_bridge_type = Float64)
    ComplexF = MOI.VectorAffineFunction{ComplexF64}
    S = SeDuMi.ScaledPSDCone
    @test MOI.supports_constraint(model, ComplexF, S)
    S = MOI.PositiveSemidefiniteConeTriangle
    @test MOI.supports_constraint(model, ComplexF, S)
    S = MOI.HermitianPositiveSemidefiniteConeTriangle
    F = MOI.VectorAffineFunction{Float64}
    @test MOI.supports_constraint(model, F, S)
    @test MOI.Bridges.bridge_type(model, F, S) ==
          MOI.Bridges.Constraint.HermitianToComplexSymmetricBridge{
        Float64,
        ComplexF,
        F,
    }
    return
end

function test_runtests()
    model = MOI.Utilities.CachingOptimizer(
        MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
        MOI.instantiate(SeDuMi.Optimizer; with_bridge_type = Float64),
    )
    @test model.optimizer.model.model_cache isa
          MOI.Utilities.UniversalFallback{SeDuMi.OptimizerCache}
    # `Variable.ZerosBridge` makes dual needed by some tests fail.
    MOI.Bridges.remove_bridge(
        model.optimizer,
        MathOptInterface.Bridges.Variable.ZerosBridge{Float64},
    )
    MOI.set(model, MOI.Silent(), true)
    MOI.Test.runtests(
        model,
        MOI.Test.Config(
            rtol = 1e-4,
            atol = 1e-4,
            exclude = Any[
                MOI.ConstraintBasisStatus,
                MOI.VariableBasisStatus,
                MOI.ObjectiveBound,
                MOI.SolverVersion,
            ],
        ),
        exclude = String[
            # Expected test failures:
            #   ArgumentError: The number of constraints must be greater than 0
            "test_attribute_RawStatusString",
            "test_attribute_SolveTimeSec",
            "test_objective_ObjectiveFunction_blank",
            "test_solve_TerminationStatus_DUAL_INFEASIBLE",
            # TODO investigate
            #  Expression: ≈(MOI.get(model, MOI.ConstraintPrimal(), c2), 0, atol = atol, rtol = rtol)
            #  Evaluated: 1.7999998823840366 ≈ 0 (atol=0.0001, rtol=0.0001)
            "test_linear_FEASIBILITY_SENSE",
            # TODO investigate
            # Incorrect solution
            "test_conic_GeometricMeanCone_VectorAffineFunction_2",
            "test_conic_GeometricMeanCone_VectorOfVariables_2",
            # TODO investigate
            # DimensionMismatch("dot product arguments have lengths 2 and 0")
            "test_conic_SecondOrderCone_negative_post_bound_2",
            "test_conic_SecondOrderCone_negative_post_bound_3",
            "test_conic_SecondOrderCone_no_initial_bound",
            # FIXME The objective has wrong sign
            # See https://github.com/jump-dev/MathOptInterface.jl/issues/1759
            "test_unbounded_MAX_SENSE",
            "test_unbounded_MAX_SENSE_offset",
            # FIXME The objective is wrong
            # See https://github.com/jump-dev/MathOptInterface.jl/issues/1759
            "test_unbounded_MIN_SENSE",
            "test_unbounded_MIN_SENSE_offset",
        ],
    )
    return
end

end  # module

TestSeDuMi.runtests()
