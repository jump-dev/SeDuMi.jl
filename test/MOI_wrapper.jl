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

function test_runtests()
    model = MOI.instantiate(SeDuMi.Optimizer, with_bridge_type=Float64)
    MOI.set(model, MOI.Silent(), true)
    MOI.Test.runtests(
        model,
        MOI.Test.Config(
            rtol = 1e-4,
            atol = 1e-4,
            exclude = Any[
                MOI.ConstraintFunction, # The bridge does not implement this
                MOI.ConstraintBasisStatus,
                MOI.VariableBasisStatus,
                MOI.ConstraintName,
                MOI.VariableName,
                MOI.ObjectiveBound,
            ],
        ),
        exclude = String[
            # Expected test failures:
            #   ArgumentError: The number of constraints must be greater than 0
            "test_attribute_RawStatusString",
            "test_attribute_SolveTimeSec",
            "test_objective_ObjectiveFunction_blank",
            "test_solve_TerminationStatus_DUAL_INFEASIBLE",
            ##   Problem is a nonconvex QP
            "test_basic_ScalarQuadraticFunction_EqualTo",
            "test_basic_ScalarQuadraticFunction_GreaterThan",
            "test_basic_ScalarQuadraticFunction_Interval",
            "test_basic_VectorQuadraticFunction_",
            "test_quadratic_SecondOrderCone_basic",
            "test_quadratic_nonconvex_",
            ##   MathOptInterface.jl issue #1431
            "test_model_LowerBoundAlreadySet",
            "test_model_UpperBoundAlreadySet",
            # FIXME
            #  Expression: ≈(MOI.get(model, MOI.ConstraintPrimal(), c2), 0, atol = atol, rtol = rtol)
            #  Evaluated: 1.7999998823840366 ≈ 0 (atol=0.0001, rtol=0.0001)
            "test_linear_FEASIBILITY_SENSE",
            # FIXME
            #  Error using pretransfo (line 149)
            #  Size b mismatch
            "test_conic_SecondOrderCone_negative_post_bound_ii",
            "test_conic_SecondOrderCone_negative_post_bound_iii",
            "test_conic_SecondOrderCone_no_initial_bound",
            # TODO investigate
            "test_conic_GeometricMeanCone_VectorAffineFunction_2",
            "test_conic_GeometricMeanCone_VectorOfVariables_2",
        ],
    )
    return
end

end  # module

TestSeDuMi.runtests()
