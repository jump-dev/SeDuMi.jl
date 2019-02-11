using Test
using SeDuMi

# Dual:
# max x
# [1 x
#  y 1] ⪰ 0
# which is transformed by SeDuMi into
# max x
# [    1   (x+y)/2
#  (x+y)/2     1  ] ⪰ 0
# Which is unbounded with the unbounded the ray (1, -1).
@testset "Semidefinite Programming example" begin
    A = -[0.0 0.0 1.0 0.0
          0.0 1.0 0.0 0.0]
    b = [1.0, 0.0]
    c = [1.0, 0.0, 0.0, 1.0]
    primal, dual, info = sedumi(A, b, c, SeDuMi.Cone(0, 0, [], [], [2]))
    @test isempty(primal)
    @test dual == [1.0, -1.0]
    @test info["pinf"] == 1.0
end
