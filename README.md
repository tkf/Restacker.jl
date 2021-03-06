# Restacker: put immutables back in the stack

[![GitHub Actions](https://github.com/tkf/ThreadsX.jl/workflows/Run%20tests/badge.svg)](https://github.com/tkf/ThreadsX.jl/actions?query=workflow%3A%22Run+tests%22)

In Julia (as of 1.4) immutable objects containing heap-allocated
objects _may not_ be stack-allocated sometimes⁽¹⁾ and that's why using
something like `view` can degrade performance substantially.
Restacker.jl provides an API

    immutable_object = restack(immutable_object)

to put `immutable_object` in the stack and avoid this performance
pitfall.

⁽¹⁾ It seems that this tends to happen when such an object crosses
non-inlined function call boundaries. See also
[this in-depth StackOverflow answer by Tim Holy](https://stackoverflow.com/a/47607539),
[this](https://discourse.julialang.org/t/stack-allocation-for-structs-with-heap-references/2293)
and
[this](https://discourse.julialang.org/t/immutables-with-reference-fields-why-boxed/7706)
discussions in Discourse and also this old PR
[JuliaLang/julia#18632](https://github.com/JuliaLang/julia/pull/18632).

## Example

Consider simple computation kernel

```julia
@noinline function f!(ys, xs)
    @inbounds for i in eachindex(ys, xs)
        x = xs[i]
        if -0.5 < x < 0.5
            ys[i] = 2x
        end
    end
end
```

This works great with raw-`Array` but the performance with `view`ed
array is not great:

```julia
julia> using BenchmarkTools

julia> xs = randn(10_000);

julia> @benchmark f!($(zero(xs)), $xs)
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     1.989 μs (0.00% GC)
  median time:      2.033 μs (0.00% GC)
  mean time:        2.189 μs (0.00% GC)
  maximum time:     6.785 μs (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     10

julia> @benchmark f!($(view(zero(xs), :)), $(view(xs, :)))
BenchmarkTools.Trial:
  memory estimate:  0 bytes
  allocs estimate:  0
  --------------
  minimum time:     47.223 μs (0.00% GC)
  median time:      49.227 μs (0.00% GC)
  mean time:        51.072 μs (0.00% GC)
  maximum time:     133.803 μs (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     1
```

It turned out that `restack`ing the destination array `ys` is enough
to fix the problem in `f!` above:

```julia
using Restacker

@noinline function g!(ys, xs)
    ys = restack(ys)
    @inbounds for i in eachindex(ys, xs)
        x = xs[i]
        if -0.5 < x < 0.5
            ys[i] = 2x
        end
    end
end
```

Calling this function on `view` is now as fast as the raw-`Vector`
version:

```julia
julia> @benchmark g!($(view(zero(xs), :)), $(view(xs, :)))
BenchmarkTools.Trial:
  memory estimate:  48 bytes
  allocs estimate:  1
  --------------
  minimum time:     2.021 μs (0.00% GC)
  median time:      2.097 μs (0.00% GC)
  mean time:        2.265 μs (0.00% GC)
  maximum time:     6.663 μs (0.00% GC)
  --------------
  samples:          10000
  evals/sample:     10
```

Notice the slight increase in the memory consumption.  This is because
`restack` re-creates the object in the stack.

See more examples in
[`benchmark/`](https://github.com/tkf/Restacker.jl/tree/master/benchmark)
directory.

## How it works

Consider an immutable type:

```julia
struct ABC{A,B,C}
    a::A
    b::B
    c::C
end
```

Then

```julia
abc = restack(abc)
```

is equivalent to

```julia
abc = ABC(
    restack(abc.a),
    restack(abc.b),
    restack(abc.c),
)
```

For mutable object like `x :: Array`, `restack` return the input as-is.

In general, `restack` is an identity function such that

```julia
restack(x) === x
```

Notice the triple-equality `===`.  It means that `restack` does not
change the behavior of the program while it may benefit run-time
performance by sacrificing the memory consumption (slightly) and
compile-time.

(Side notes: There is an even more experimental function
`Restacker.unsafe_restack` to re-construct `mutable struct` as well.
This is unsafe because it breaks the identity (`===`) and breaks the
assumption of the code relying on `finalize`.)

Under the hood, `restack` on `struct` types work by directly invoking
the
[`new` expression](https://docs.julialang.org/en/latest/devdocs/ast/#Expr-types-1).
This skips evaluating user-defined constructors and minimizes the
run-time overhead.
