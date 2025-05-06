# Copyright (c) 2017: Benoît Legat and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestSeDuMi

using Test
import MathOptInterface as MOI
import SeDuMi

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

function test_complex_bridges()
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

function test_complex()
    model = MOI.instantiate(SeDuMi.Optimizer; with_cache_type = Float64)
    x = MOI.add_variable(model)
    T = ComplexF64
    c = MOI.add_constraint(
        model,
        MOI.Utilities.vectorize([
            one(T) + zero(T) * x,
            -1.0im *  x,
            1.0im *  x,
            one(T) + zero(T) * x,
        ]),
        SeDuMi.ScaledPSDCone(2),
    )
    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    obj = 1.0 * x
    MOI.set(model, MOI.ObjectiveFunction{typeof(obj)}(), obj)
    MOI.optimize!(model)
    @test MOI.get(model, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test MOI.get(model, MOI.VariablePrimal(), x) ≈ 1 rtol = 1e-5
    @test MOI.get(model, MOI.ConstraintPrimal(), c) ≈ [1, -im, im, 1] rtol = 1e-5
    @test MOI.get(model, MOI.ConstraintDual(), c) ≈ [0.5, 0.5im, -0.5im, 0.5] rtol = 1e-5
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
        MOI.Bridges.Variable.ZerosBridge{Float64},
    )
    MOI.set(model, MOI.Silent(), true)
    MOI.Test.runtests(
        model,
        MOI.Test.Config(
            rtol = 5e-3,
            atol = 5e-3,
            exclude = Any[
                MOI.ConstraintBasisStatus,
                MOI.VariableBasisStatus,
                MOI.ObjectiveBound,
                MOI.SolverVersion,
            ],
        ),
        exclude = [
            # Expected test failures:
            #   ArgumentError: The number of constraints must be greater than 0
            "test_attribute_RawStatusString",
            "test_attribute_SolveTimeSec",
            "test_objective_ObjectiveFunction_blank",
            "test_solve_TerminationStatus_DUAL_INFEASIBLE",
            # Out of memory.
            "test_conic_empty_matrix",
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
            r"^test_unbounded_MAX_SENSE$",
            r"^test_unbounded_MAX_SENSE_offset$",
            # FIXME The objective is wrong
            # See https://github.com/jump-dev/MathOptInterface.jl/issues/1759
            r"^test_unbounded_MIN_SENSE$",
            r"^test_unbounded_MIN_SENSE_offset$",
        ],
    )
    return
end

end  # module

TestSeDuMi.runtests()
