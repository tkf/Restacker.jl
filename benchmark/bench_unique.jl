module BenchUnique

using BenchmarkTools
using Restacker: restack

@noinline unique_norestack(xs) = first(unique_impl_norestack(xs))

@noinline unique_impl_norestack(xs) =
    unique_impl_norestack!((Set{eltype(xs)}(), eltype(xs)[]), xs)

function unique_impl_norestack!(dest, xs)
    for x in xs
        ys, seen = dest
        if !(x in seen)
            push!(seen, x)
            push!(ys, x)
        end
        dest = ys, seen  # this degrades the performance
    end
    return dest
end

@noinline unique_restack(xs) = first(unique_impl_restack(xs))

@noinline unique_impl_restack(xs) =
    unique_impl_restack!((Set{eltype(xs)}(), eltype(xs)[]), xs)

function unique_impl_restack!(dest, xs)
    for x in xs
        ys, seen = dest
        if !(x in seen)
            push!(seen, x)
            push!(ys, x)
        end
        dest = ys, seen
    end
    return restack(dest)
end

suite = BenchmarkGroup()

xs = rand(1:10, 1_000)
suite["norestack"] = @benchmarkable unique_norestack($xs)
suite["restack"] = @benchmarkable unique_restack($xs)

end  # module
BenchUnique.suite
