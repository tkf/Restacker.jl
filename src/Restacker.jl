module Restacker

export restack, hard_restack

"""
    restack(x) -> x

An identity function in the sense `restack(x) === x`.  However, it
(recursively) re-construct `x` to beg the compiler to move everything
in the stack.
"""
restack
restack(x) = _restack(x, Val(false))

"""
    hard_restack(x) -> x

Like `restack(x)` but works for mutable objects, too. Thus, this is
the identity function only w.r.t (at most) `isequal`.
"""
hard_restack
hard_restack(x) = _restack(x, Val(true))

_getlength(::Type{<:NTuple{N,Any}}) where {N} = N
_getnames(::Type{<:NamedTuple{names}}) where {names} = names

# Not using dispatch, to check `issingletontype` first.
@generated function _restack(x, ::Val{hard}) where {hard}
    if Base.issingletontype(x)
        ex = x.instance::x
    elseif x <: Tuple
        N = _getlength(x)
        ex = :(($(map(i -> :(_restack(x[$i], Val{$hard}())), 1:N)...),))
    elseif x <: NamedTuple
        names = _getnames(x)
        ex = :((; $(map(n -> Expr(:kw, n, :(_restack(x.$n, Val{$hard}()))), names)...)))
    elseif parentmodule(x) === Core
        # Workaround the issue with `isstructtype(String)` and
        #  `isstructtype(Symbol)`.
        # https://github.com/JuliaLang/julia/issues/30210
        ex = :x
    elseif isstructtype(x)
        new = Expr(:new, x, map(n -> :(_restack(x.$n, Val{$hard}())), fieldnames(x))...)
        if hard === true
            ex = new
        else
            ex = quote
                isimmutable(x) ? $new : x
            end
        end
    else
        ex = :x
    end
    return Expr(:block, Expr(:meta, :inline), ex)
end

end # module
