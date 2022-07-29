using Symbolics
using Test

using Random

@variables x y z

@testset "SemiMonomial constructor" begin
    c = 4
    ds = [1, 2]
    T = Rational{Int32}
    m = Symbolics.SemiMonomial{T}(c, ds)
    @test c == m.coeff
    @test ds == m.degrees
    @test Int == typeof(m.coeff)
    @test Int == eltype(m.degrees)
end

@testset "SemiMonomial +" begin
    a = Symbolics.SemiMonomial{Int64}(3, [1, 2])
    b = Symbolics.SemiMonomial{Rational{Int32}}(4, [-1, 2.0])
    t = a + b
    @test t isa SymbolicUtils.Term
    @test operation(t) == +
    @test arguments(t) == [a, b]
    @test Symbolics.symtype(t) == Rational{Int64}

    c = Symbolics.SemiMonomial{Float32}(4, [-1, 2.0])
    s = c + t
    @test s isa SymbolicUtils.Term
    @test operation(s) == +
    @test arguments(s) == [a, b, c]
    @test Symbolics.symtype(s) == Float32
end

@testset "SemiMonomial *" begin
    a = Symbolics.SemiMonomial{Int64}(3, [1, 2])
    b = Symbolics.SemiMonomial{Rational{Int32}}(4.0, [-1.0, 1//2])
    m = a * b
    @test m isa Symbolics.SemiMonomial{Rational{Int64}}
    @test m.coeff == 12.0
    @test m.degrees == [0.0, 5//2]
end

@testset "SemiMonomial /" begin
    a = Symbolics.SemiMonomial{Float32}(3, [1, 2])
    b = Symbolics.SemiMonomial{Rational{Int64}}(4.0, [-1.0, 1//2])
    m = a / b
    @test m isa Symbolics.SemiMonomial{Float32}
    @test m.coeff == 0.75
    @test m.degrees == [2.0, 3//2]
end

@testset "SemiMonomial ^" begin
    a = Symbolics.SemiMonomial{Int32}(4.0, [-1.0, 1//2])
    b = 3
    e = a^b
    @test e isa Symbolics.SemiMonomial{Int64}
    @test e.coeff == 64.0
    @test e.degrees == [-3.0, 3//2]

    c = -0.7
    m = a^c
    @test m isa Symbolics.SemiMonomial{Float64}
    @test m.coeff == 4.0^-0.7
    @test m.degrees == [0.7, -0.35]
end

@testset "SemiMonomial isreal" begin
    a = Symbolics.SemiMonomial{Int32}(4.0, [-1.0, 1//2])
    @test !isreal(a)

    b = Symbolics.SemiMonomial{Int32}(9, [-0.0, 0//1])
    @test isreal(b)

    c = Symbolics.SemiMonomial{Int32}(tan(x), [-0.0, 0//1])
    @test !isreal(c)
end

@testset "SemiMonomial real" begin
    b = Symbolics.SemiMonomial{Int32}(9, [-0.0, 0//1])
    @test real(b) == 9
end

@testset "tomonomial" begin
    a = Symbolics.SemiMonomial{Real}(3, [1, 2])
    m = Symbolics.tomonomial(a, [x, y])
    @test isequal(m, x * y^2)

    b = Symbolics.SemiMonomial{Real}(z, [0.0, 0.0])
    n = Symbolics.tomonomial(b, [x, y])
    @test n == 1

    c = Symbolics.SemiMonomial{Real}(4.0, [1//2, 2.0])
    @test_throws InexactError Symbolics.tomonomial(c, [x, y])

    d = Symbolics.SemiMonomial{Real}(9.0, [0.0, 4])
    r = Symbolics.tomonomial(d, [x, y])
    @test isequal(r, y^4)
end

@testset "simple expressions" begin
    d, r = semipolynomial_form(x, [x], 1)
    @test d == Dict(x => 1)
    @test r == 0

    d, r = semipolynomial_form(x + sin(x) + 1 + y, [x], 1)
    @test isequal(d, Dict(1 => 1 + y, x => 1))
    @test isequal(r, sin(x))

    d, r = semipolynomial_form(x^2 + 1 + y, [x], 1)
    @test isequal(d, Dict(1 => 1 + y))
    @test isequal(r, x^2)

    d, r = semipolynomial_form((x + 2)^12, [x], 1)
    @test isequal(d, Dict(1 => 1 << 12, x => (1 << 11) * 12))
end

@testset "maintein SymbolicUtils.Symbolic subtype" begin
    pow_expr = 7^(3y + sin(y))
    @test SymbolicUtils.ispow(Symbolics.unwrap(pow_expr))
    dict, nl = semipolynomial_form(pow_expr, [y], Inf)
    @test isempty(dict)
    # expect a SymbolicUtils.Pow object instead of SymbolicUtils.Term with f = ^
    @test isequal(nl, pow_expr)
    @test SymbolicUtils.ispow(nl)

    mul_expr = 9 * 7^y * sin(x)^4 * tan(x + y)^3
    @test SymbolicUtils.ismul(Symbolics.unwrap(mul_expr))
    dict, nl = semipolynomial_form(mul_expr, [x, y], Inf)
    @test isempty(dict)
    # expect a SymbolicUtils.Mul object instead of SymbolicUtils.Term with f = *
    @test isequal(nl, mul_expr)
    @test SymbolicUtils.ismul(nl)

    div_expr = x / y
    @test SymbolicUtils.isdiv(Symbolics.unwrap(div_expr))
    dict, nl = semipolynomial_form(div_expr, [x, y], Inf)
    @test isempty(dict)
    # expect a SymbolicUtils.Div object instead of SymbolicUtils.Term with f = /
    @test isequal(nl, div_expr)
    @test SymbolicUtils.isdiv(nl)
    dict, nl = semipolynomial_form(div_expr, [x], Inf)
    @test isequal(dict, Dict(x => 1 / y))
    @test iszero(nl)
    dict, nl = semipolynomial_form(div_expr, [y], Inf)
    @test isempty(dict)
    @test isequal(nl, div_expr)
end

@testset "negative exponent" begin
    # `SymbolicUtils.Pow` object with a negative exponent normally cannot be created.
    # For example, `x^-1` returns `1 / x` which is a `SymbolicUtils.Div`.
    # But `expand_derivatives` may result in a `SymbolicUtils.Pow` with a negative exponent.
    sqrt_x = sqrt(x)
    deriv = expand_derivatives(Differential(x)(sqrt_x)) # (1//2)*(sqrt(x)^-1)
    expr = substitute(deriv, Dict(sqrt_x => y)) # (1//2)*(y^-1)
    d, r = semipolynomial_form(expr, [x, y], Inf)
    @test isempty(d)
end

@testset "constants as 0-degree monomials" begin
    # expect no ArgumentError when degree = 0 and consts = true
    @test_broken semipolynomial_form(1 + x, [x], 0, true)

    d, r = semipolynomial_form(1 + x + y, [x], 1, true)
    @test length(d) == 2
    @test iszero(r)
    @test isequal(d[1], 1 + y)
    @test d[x] == 1

    d, r = semipolynomial_form(1 + x + y, [x, y], 1, true)
    @test length(d) == 3
    @test iszero(r)
    @test d[1] == 1
    @test d[x] == 1
    @test d[y] == 1

    expr = 4(1 + x + y)^3
    lin, nl = semipolynomial_form(expr, [x], 1, true)
    @test length(lin) == 2
    @test haskey(lin, x)
    @test haskey(lin, 1)
    @test isequal(lin[x], 12(1 + y)^2) || isequal(lin[x], 12 + 24y + 12y^2)
    @test isequal(lin[1], 4(1 + y)^3) || isequal(lin[1], 4 + 12y + 12y^2 + 4y^3)

    @testset "type $T degree $degree" for T in [Float32, Float64, Int32, Int64, UInt32,
                                                UInt64, Rational],
                                          degree in [1, 2, Inf]
        expr = one(T)
        d, r = semipolynomial_form(expr, [], degree, true)
        @test iszero(r)
        @test length(d) == 1
        @test d[1] isa T
        @test expr == d[1]

        expr = one(T) + x + x^y + sin(x)
        d, r = semipolynomial_form(expr, [x], degree, true)
        @test isequal(r, x^y + sin(x))
        @test length(d) == 2
        # @test d[1] isa T
        @test isone(d[1])
        @test d[x] == 1
    end
end

@syms a b c

const components = [2, a, b, c, x, y, z, (1+x), (1+y)^2, z*y, z*x]

function verify(t, d, wrt, nl)
    try
        iszero(t - (isempty(d) ? nl : sum(k*v for (k, v) in d) + nl))
    catch err
        println("""Error verifying semi-pf result for $t
                 wrt = $wrt
                 d = $d
                 nl = $nl""")
        rethrow(err)
    end
end

seed = 0

function trial()
    global seed += 1
    Random.seed!(666+seed)
    n = rand(2:length(components)-1)
    l, r = rand(components, n), vcat(rand(components, n), [1, 0, 1//2, 1.5])

    t = *(map(1:rand(1:3)) do _
        pow = rand([1,1,1,1,1,1,1,1,2,3])
        nterms = rand(2:5)
        sum(rand(l, nterms) .* rand(r, nterms)) ^ pow
    end...)

    @show t

    for _ = 1:4
        wrt = unique(rand([a,b,c,x,y,z], rand(1:6)))
        for deg=Any[1,2,3,4,Inf]
            if deg == 1
                A, c = semilinear_form([t], wrt)
                res = iszero(A*wrt + c - [t])
                if !res
                    println("Semi-linear form is wrong: [$t]  w.r.t   $wrt ")
                    @show A c
                end
            elseif deg == 2
                A,B,v2, c = semiquadratic_form([t], wrt)
                res = iszero(A * wrt + B * v2 + c - [t])
                if !res
                    println("Semi-quadratic form is wrong: $t  w.r.t   $wrt")
                    @show A B v2 c
                end
            else
                if isfinite(deg)
                    d, nl = semipolynomial_form(t, wrt, deg)
                    @test all(x->Symbolics.pdegree(x) <= deg, keys(d))
                    for x in wrt
                        d2, enl = semipolynomial_form(expand(nl), wrt, Inf)
                        elim = all(x->Symbolics.pdegree(x)>deg, keys(d2))
                        if !elim
                            println("Imperfect elimination:")
                            @show t wrt deg nl expand(nl)
                        end
                        @test elim
                    end
                else
                    d, nl = polynomial_coeffs(t, wrt)
                end

                res = verify(t, d, wrt, nl)
                if !res
                    println("""Semi-poly form is wrong: $t  w.r.t   $wrt  deg=$deg
                            Result: $d + $nl""")
                end
            end

            @test res
        end
    end
end

for i=1:20
    @testset "fuzz semi-polynomial-form ($i/20)" begin
        trial()
    end
end
