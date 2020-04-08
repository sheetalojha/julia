# This file is a part of Julia. License is MIT: https://julialang.org/license

using Test, Base.Threads
using Core: ConcurrencyViolationError
import Base: copy

mutable struct ARefxy{T}
    @atomic x::T
    y::T
end

mutable struct Refxy{T}
    x::T
    y::T
end

@test_throws ErrorException("invalid redefinition of constant ARefxy") @eval mutable struct ARefxy{T}
    @atomic x::T
    @atomic y::T
end
@test_throws ErrorException("invalid redefinition of constant ARefxy") @eval mutable struct ARefxy{T}
    x::T
    y::T
end
@test_throws ErrorException("invalid redefinition of constant ARefxy") @eval mutable struct ARefxy{T}
    x::T
    @atomic y::T
end
@test_throws ErrorException("invalid redefinition of constant Refxy") @eval mutable struct Refxy{T}
    x::T
    @atomic y::T
end

copy(r::Union{Refxy,ARefxy}) = typeof(r)(r.x, r.y)

# check that very large types are getting locks
let (x, y) = (Complex{Int128}(10, 30), Complex{Int128}(20, 40))
    ar = ARefxy(x, y)
    r = Refxy(x, y)
    @test 64 == sizeof(r) < sizeof(ar)
    @test sizeof(r) == sizeof(ar) - Int(fieldoffset(typeof(ar), 1))
end

@noinline function _test_field_orderings(r, x, y)
    @nospecialize x y
    r = r[]
    @test getfield(r, :x) === x
    @test_throws ConcurrencyViolationError("invalid atomic ordering") getfield(r, :y, :u)
    @test getfield(r, :y, :none) === y
    @test_throws ConcurrencyViolationError("getfield non-atomic field cannot be accessed atomically") getfield(r, :y, :unordered)
    @test_throws ConcurrencyViolationError("getfield non-atomic field cannot be accessed atomically") getfield(r, :y, :monotonic)
    @test_throws ConcurrencyViolationError("getfield non-atomic field cannot be accessed atomically") getfield(r, :y, :acquire)
    @test_throws ConcurrencyViolationError("getfield non-atomic field cannot be accessed atomically") getfield(r, :y, :release)
    @test_throws ConcurrencyViolationError("getfield non-atomic field cannot be accessed atomically") getfield(r, :y, :acquire_release)
    @test_throws ConcurrencyViolationError("getfield non-atomic field cannot be accessed atomically") getfield(r, :y, :sequentially_consistent)

    @test_throws ConcurrencyViolationError("setfield! atomic field cannot be written non-atomically") setfield!(r, :x, y)
    @test_throws ConcurrencyViolationError("invalid atomic ordering") setfield!(r, :x, y, :u)
    @test_throws ConcurrencyViolationError("setfield! atomic field cannot be written non-atomically") setfield!(r, :x, y, :none)
    @test getfield(r, :x) === x
    @test setfield!(r, :x, y, :unordered) === y
    @test setfield!(r, :x, y, :monotonic) === y
    @test setfield!(r, :x, y, :acquire) === y
    @test setfield!(r, :x, y, :release) === y
    @test setfield!(r, :x, y, :acquire_release) === y
    @test setfield!(r, :x, y, :sequentially_consistent) === y
    @test getfield(r, :x) === y

    @test_throws ConcurrencyViolationError("invalid atomic ordering") setfield!(r, :y, x, :u)
    @test_throws ConcurrencyViolationError("setfield! non-atomic field cannot be written atomically") setfield!(r, :y, x, :unordered)
    @test_throws ConcurrencyViolationError("setfield! non-atomic field cannot be written atomically") setfield!(r, :y, x, :monotonic)
    @test_throws ConcurrencyViolationError("setfield! non-atomic field cannot be written atomically") setfield!(r, :y, x, :acquire)
    @test_throws ConcurrencyViolationError("setfield! non-atomic field cannot be written atomically") setfield!(r, :y, x, :release)
    @test_throws ConcurrencyViolationError("setfield! non-atomic field cannot be written atomically") setfield!(r, :y, x, :acquire_release)
    @test_throws ConcurrencyViolationError("setfield! non-atomic field cannot be written atomically") setfield!(r, :y, x, :sequentially_consistent)
    @test getfield(r, :y) === y
    @test setfield!(r, :y, x) === x
    @test setfield!(r, :y, x, :none) === x
    @test getfield(r, :y) === x
    nothing
end
@noinline function test_field_orderings(r, x, y)
    _test_field_orderings(Ref(copy(r)), x, y)
    _test_field_orderings(Ref{Any}(copy(r)), x, y)
    nothing
end
@noinline test_field_orderings(x, y) = (@nospecialize; test_field_orderings(ARefxy(x, y), x, y))
test_field_orderings(10, 20)
test_field_orderings("hi", "bye")
test_field_orderings(:hi, :bye)
test_field_orderings(nothing, nothing)
test_field_orderings(ARefxy{Union{Nothing,Missing}}(nothing, missing), nothing, missing)
test_field_orderings(ARefxy{Union{Nothing,Int}}(nothing, 1), nothing, 1)
test_field_orderings(Complex{Int128}(10, 30), Complex{Int128}(20, 40))

@noinline function test_field_operators(r)
    r = r[]
    @test getfield(r, :x, :sequentially_consistent) === 10
    @test setfield!(r, :x, 1, :sequentially_consistent) === 1
    @test getfield(r, :x, :sequentially_consistent) === 1
    #@test cmpswap(r, :x, :sequentially_consistent) === 1
    #@test atomics_pointercmpxchg(r, 100, 1, :sequentially_consistent, :sequentially_consistent) === true
    #@test atomics_pointerref(r, :sequentially_consistent) === 100
    #@test atomics_pointercmpxchg(r, 1, 1, :sequentially_consistent, :sequentially_consistent) === false
    #@test atomics_pointerref(r, :sequentially_consistent) === 100
    #@test atomics_pointerop(r, 1, +, :sequentially_consistent) == 100
    #@test atomics_pointerop(r, 1, +, :sequentially_consistent) == 101
    #@test atomics_pointerref(r, :sequentially_consistent) == 102
end
test_field_operators(Ref(ARefxy{Int}(10, 20)))
test_field_operators(Ref{Any}(ARefxy{Int}(10, 20)))
