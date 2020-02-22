using InteractiveUtils: code_llvm
using Restacker: restack
using Test

"""
    llvm_ir(f, args) :: String

Get LLVM IR of `f(args...)` as a string.
"""
llvm_ir(f, args) = sprint(code_llvm, f, Base.typesof(args...))

nmatches(r, s) = count(_ -> true, eachmatch(r, s))


@noinline function filter_map_restack!(ys, xs)
    ys = restack(ys)
    xs = restack(xs)
    @inbounds for i in eachindex(ys, xs)
        x = xs[i]
        if -0.5 < x < 0.5
            ys[i] = 2x
        end
    end
end

@testset "filter_map" begin
    ir = llvm_ir(filter_map_restack!, (Float64[], Float64[]))
    @debug "filter_map_restack!" LLVM_IR = Text(ir)
    @test nmatches(r"fmul <[0-9]+ x double>", ir) >= 4
    @test nmatches(r"fcmp [a-z]* <[0-9]+ x double>", ir) >= 4
end
