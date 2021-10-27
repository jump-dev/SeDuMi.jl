using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.DeprecatedTest
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

import SeDuMi
const OPTIMIZER_CONSTRUCTOR = MOI.OptimizerWithAttributes(SeDuMi.Optimizer, MOI.Silent() => true)
const OPTIMIZER = MOI.instantiate(OPTIMIZER_CONSTRUCTOR)

@testset "SolverName" begin
    @test MOI.get(OPTIMIZER, MOI.SolverName()) == "SeDuMi"
end

const BRIDGED = MOI.instantiate(OPTIMIZER_CONSTRUCTOR, with_bridge_type=Float64)
const CONFIG = MOIT.Config(atol=1e-4, rtol=1e-4)

@testset "Unit" begin
    MOIT.unittest(BRIDGED, CONFIG, [
        # `NumberOfThreads` not supported.
        "number_threads",
        # `TimeLimitSec` not supported.
        "time_limit_sec",
        # Error using pretransfo (line 149)
        # Size b mismatch
        "solve_unbounded_model",
        # Need https://github.com/jump-dev/MathOptInterface.jl/issues/529
        "solve_qp_edge_cases",
        # Integer and ZeroOne sets are not supported
        "solve_integer_edge_cases", "solve_objbound_edge_cases",
        "solve_zero_one_with_bounds_1",
        "solve_zero_one_with_bounds_2",
        "solve_zero_one_with_bounds_3"])
end

@testset "Continuous linear problems" begin
    MOIT.contlineartest(BRIDGED, CONFIG, ["linear13"]) # See https://github.com/blegat/SeDuMi.jl/issues/7
end

@testset "Continuous conic problems" begin
    MOIT.contconictest(BRIDGED, CONFIG, [
        # Unsupported cones
        "pow", "dualpow", "rootdets", "exp", "dualexp", "logdet", "normspec", "normnuc", "relentr",
        # TODO investigate
        "geomean2v", "geomean2f"
    ])
end
