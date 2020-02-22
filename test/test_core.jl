module TestCore

using Test
using Restacker: restack, hard_restack

struct ABC{A,B,C}
    a::A
    b::B
    c::C
end

function testlabel(x)
    n = 50
    s = string(x)
    length(s) < n && return s
    label = join(Iterators.take(s, n))
    return string(label, "…")
end

@testset "$(testlabel(x))" for x in Any[
    nothing,
    missing,
    1,
    1.0,
    NaN,
    1+2im,
    :symbol,
    "string",
    (nothing, missing, 1, 1.0, NaN, 1 + 2im, :symbol, "string"),
    (Val(1), Val(2), nothing, missing, undef),
    (
        a = (nothing, missing, 1, 1.0, NaN, 1 + 2im, :symbol, "string"),
        b = (Val(1), Val(2), nothing, missing, undef),
    ),
    ABC(
        (nothing, missing, 1, 1.0, NaN, 1 + 2im, :symbol, "string"),
        (Val(1), Val(2), nothing, missing, undef),
        (d = 1, e = ABC(1, 2, 3)),
    ),
]
    @test restack(x) === x
    @test hard_restack(x) === x
end

@testset "$(testlabel(x))" for x in Any[
    Dict(:a => 1, :b => 2),
    Set([1, 2]),
    (Dict(:a => 1, :b => 2), Set([1, 2])),
    (Dict(:a => 1, :b => 2), Set([1, 2]), missing),
    (a = Dict(:a => 1, :b => 2), b = Set([1, 2]), c = ABC(1, 2, 3)),
]
    if (x == x) === true
        @test hard_restack(x) == x
    end
    @test isequal(hard_restack(x), x)
end

end  # module
