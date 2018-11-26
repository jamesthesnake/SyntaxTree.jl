__precompile__()
module SyntaxTree

#   This file is part of SyntaxTree.jl. It is licensed under the MIT license
#   Copyright (C) 2018 Michael Reed

export linefilter, callcount, genfun, @genfun

"""
    linefilter(::Expr)

Recursively filters out :line blocks from Expr objects
"""
@noinline function linefilter(expr::Expr)
    total = length(expr.args)
    i = 0
    while i < total
        i += 1
        if expr.args[i] |> typeof == Expr
            if expr.args[i].head == :line
                deleteat!(expr.args,i)
                total -= 1
                i -= 1
            else
                expr.args[i] = linefilter(expr.args[i])
            end
        elseif expr.args[i] |> typeof == LineNumberNode
            deleteat!(expr.args,i)
            total -= 1
            i -= 1
        end
    end
    return expr
end

"""
    sub(T::DataType,expr::Expr)

Make a substitution to convert numerical values to type T
"""
@noinline function sub(T::DataType,expr)
    if typeof(expr) == Expr
        ixpr = deepcopy(expr)
        if ixpr.head == :call && ixpr.args[1] == :^
            ixpr.args[2] = sub(T,ixpr.args[2])
            if typeof(ixpr.args[3]) == Expr
                ixpr.args[3] = sub(T,ixpr.args[3])
            end
        elseif ixpr.head == :macrocall &&
                ixpr.args[1] ∈ [Symbol("@int128_str"), Symbol("@big_str")]
            return convert(T,eval(ixpr))
        else
            for a ∈ 1:length(ixpr.args)
                ixpr.args[a] = sub(T,ixpr.args[a])
            end
        end
        return ixpr
    elseif typeof(expr) <: Number
        return convert(T,expr)
    end
    return expr
end

"""
    SyntaxTree.abs(expr)

Apply `abs` to the expression recursively
"""
@noinline function abs(expr)
    if typeof(expr) == Expr
        ixpr = deepcopy(expr)
        if ixpr.head == :call && ixpr.args[1] == :^
            ixpr.args[2] = abs(ixpr.args[2])
            if typeof(ixpr.args[3]) == Expr
                ixpr.args[3] = abs(ixpr.args[3])
            end
        elseif ixpr.head == :macrocall &&
                ixpr.args[1] ∈ [Symbol("@int128_str"), Symbol("@big_str")]
            return Base.abs(ixpr)
        else
            ixpr.head == :call && ixpr.args[1] == :- && (ixpr.args[1] = :+)
            for a ∈ 1:length(ixpr.args)
                ixpr.args[a] = abs(ixpr.args[a])
            end
        end
        return ixpr
    elseif typeof(expr) <: Number
        return Base.abs(expr)
    end
    return expr
end

"""
    alg(expr,f=:(1+ϵ))

Recursively substitutes a multiplication by (1+ϵ) per call in `expr`
"""
@noinline function alg(expr,f=:(1+ϵ))
    if typeof(expr) == Expr
        ixpr = deepcopy(expr)
        if ixpr.head == :call
            ixpr.args[2:end] = alg.(ixpr.args[2:end],Ref(f))
            ixpr = Expr(:call,:*,f,ixpr)
        end
        return ixpr
    else
        return expr
    end
end

"""
    @genfun(expr, args)

Returns an anonymous function based on the given `expr` and `args`.

```Julia
julia> @genfun x^2+y^2 [x,y]
```
"""
macro genfun(expr,args...); :(($(args...),)->$expr) end

"""
    genfun(expr, args::Array)

Returns an anonymous function based on the given `expr` and `args`.

```Julia
julia> genfun(:(x^2+y^2),[:x,:y])
```
"""
genfun(expr,args::Array) = eval(:(($(args...),)->$expr))
genfun(expr,arg::Symbol) = eval(:($arg->$expr))

"""
    callcount(expr)

Returns a count of the `call` operations in `expr`.
"""
@noinline function callcount(expr)
    c = 0
    if typeof(expr) == Expr
        expr.head == :call && (c += 1)
        c += sum(callcount.(expr.args))
    end
    return c
end

include("exprval.jl")

__init__() = nothing

end # module
