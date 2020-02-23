module BenchFilterMap

using BenchmarkTools
using Restacker: restack

@noinline function filter_map_norestack!(ys, xs)
    @inbounds for i in eachindex(ys, xs)
        x = xs[i]
        if -0.5 < x < 0.5
            ys[i] = 2x
        end
    end
end

@noinline function filter_map_restack!(ys, xs)
    ys = restack(ys)
    @inbounds for i in eachindex(ys, xs)
        x = xs[i]
        if -0.5 < x < 0.5
            ys[i] = 2x
        end
    end
end

suite = BenchmarkGroup()

xs = view(randn(10_000), :)
ys = view(randn(10_000), :)
suite["norestack"] = @benchmarkable filter_map_norestack!($ys, $xs)
suite["restack"] = @benchmarkable filter_map_restack!($ys, $xs)

end  # module
BenchFilterMap.suite
