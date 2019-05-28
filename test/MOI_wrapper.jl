using Test

using MathOptInterface
const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges

import SeDuMi
const optimizer = SeDuMi.Optimizer(fid=0)

@testset "SolverName" begin
    @test MOI.get(optimizer, MOI.SolverName()) == "SeDuMi"
end

@testset "supports_allocate_load" begin
    @test MOIU.supports_allocate_load(optimizer, false)
    @test !MOIU.supports_allocate_load(optimizer, true)
end

MOIU.@model(ModelData, (), (),
            (MOI.Zeros, MOI.Nonnegatives, MOI.SecondOrderCone,
             MOI.RotatedSecondOrderCone, MOI.PositiveSemidefiniteConeTriangle),
            (), (), (), (MOI.VectorOfVariables,), (MOI.VectorAffineFunction,))

# UniversalFallback is needed for starting values, even if they are ignored by SeDuMi
const cache = MOIU.UniversalFallback(ModelData{Float64}())
const cached = MOIU.CachingOptimizer(cache, optimizer)

const bridged = MOIB.full_bridge_optimizer(cached, Float64)

config = MOIT.TestConfig(atol=1e-4, rtol=1e-4)

@testset "Unit" begin
    MOIT.unittest(MOIB.SplitInterval{Float64}(bridged),
                  config,
                  [# Quadratic functions are not supported
                   "solve_qcp_edge_cases", "solve_qp_edge_cases",
                   # Integer and ZeroOne sets are not supported
                   "solve_integer_edge_cases", "solve_objbound_edge_cases"])
end

@testset "Continuous linear problems" begin
    MOIT.contlineartest(MOIB.SplitInterval{Float64}(bridged),
                        config,
                        ["linear13"] # See https://github.com/blegat/SeDuMi.jl/issues/7
                       )
end

@testset "Continuous conic problems" begin
    MOIT.contconictest(MOIB.SquarePSD{Float64}(MOIB.RootDet{Float64}(MOIB.GeoMean{Float64}(bridged))),
                       config, ["rootdets", "exp", "logdet"])
end
