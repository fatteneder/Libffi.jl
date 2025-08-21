using Test


import Base.Libc
import Libdl
import Libffi


const libccalltest = joinpath(Libffi.SCRATCH_DIR[], "libccalltest.so")
const libmwes = joinpath(Libffi.SCRATCH_DIR[], "libmwes.so")


@testset "libffi.ffi_type" begin
    ctypes = Any[
        Cvoid, Cuchar, Cshort, Cint, Cuint, Cfloat,
        Cdouble, Cuint, Cfloat, Cdouble, Clonglong, Culonglong,
        ComplexF32, ComplexF64,
    ]
    for ct in ctypes
        p = Libffi.ffi_type(ct)
        @test p != C_NULL
    end
end


@testset "error handling" begin
    # return-on-copy requires concrete type
    @test_throws ArgumentError Libffi.Ffi_cif(AbstractArray, (Cint,))
    # Ref{Any} is invalid argtype, use Ptr{Any}
    @test_throws ArgumentError Libffi.Ffi_cif(Ref{Any}, (Cint,))
end


@testset "ffi_call with only C types" begin
    handle = Libdl.dlopen(libmwes)

    cif = Libffi.Ffi_cif(Cint, (Cint,))
    fn = Libdl.dlsym(handle, :mwe_my_square)
    result = Libffi.ffi_call(cif, fn, [Int32(123)])
    expected = Int32(123)^2
    @test result == expected

    cif = Libffi.Ffi_cif(Cint, (Ptr{Cint},))
    fn = Libdl.dlsym(handle, :mwe_my_square_w_ptr_arg)
    result = Libffi.ffi_call(cif, fn, [[Int32(123)]])
    expected = Int32(123)^2
    @test result == expected

    cif = Libffi.Ffi_cif(Cvoid, ())
    fn = Libdl.dlsym(handle, :mwe_do_nothing)
    result = Libffi.ffi_call(cif, fn, [])
    expected = nothing
    @test result == expected

    cif = Libffi.Ffi_cif(Ptr{Cint}, (Cint,))
    fn = Libdl.dlsym(handle, :mwe_alloc_an_array)
    p = C_NULL
    try
        p = Libffi.ffi_call(cif, fn, [5])
        @test p !== C_NULL
        result = unsafe_wrap(Vector{Int32}, p, (5,))
        expected = [ Int32(i - 1) for i in 1:5 ]
        @test result == expected
    finally
        p !== C_NULL && Libc.free(p)
    end

    @test_throws ArgumentError("Encountered bad argument type Cvoid") Libffi.Ffi_cif(Cvoid, (Cvoid,))
end


mutable struct FFI_MutDummy
    x::String
    y::Int64
end
struct FFI_ImmutDummy
    x::String
    y::Int64
end
mutable struct my_type
    x::Cint
end
@testset "ffi_call with Julia types" begin
    handle = Libdl.dlopen(libmwes)

    cif = Libffi.Ffi_cif(Clonglong, (Any,))
    fn = Libdl.dlsym(handle, :mwe_my_square_jl)
    result = Libffi.ffi_call(cif, fn, [123])
    expected = 123^2
    @test result == expected

    # mutable type
    cif = Libffi.Ffi_cif(Clonglong, (Any,))
    fn = Libdl.dlsym(handle, :mwe_accept_jl_type)
    x = FFI_MutDummy("sers", 12321)
    result = Libffi.ffi_call(cif, fn, [x])
    expected = 12321
    @test result == expected

    # immutable type
    cif = Libffi.Ffi_cif(Clonglong, (Any,))
    fn = Libdl.dlsym(handle, :mwe_accept_jl_type)
    x = FFI_ImmutDummy("sers", 12321)
    result = Libffi.ffi_call(cif, fn, [x])
    expected = 12321
    @test result == expected

    cif = Libffi.Ffi_cif(Int64, (Complex{Int64},))
    fptr = Libdl.dlsym(handle, :mwe_ctest_jl_arg_c_ret)
    c = Complex{Int64}(20, 51)
    result = Libffi.ffi_call(cif, fptr, [c])
    @test result == 20 + 51

    cif = Libffi.Ffi_cif(Complex{Int64}, (Int64, Int64))
    fptr = Libdl.dlsym(handle, :mwe_ctest_c_arg_jl_ret)
    result = Libffi.ffi_call(cif, fptr, [20, 51])
    @test result == c

    println("trying @ccall version first!")
    fn = Libdl.dlsym(handle, :mwe_jl_alloc_genericmemory_carg)
    result = @ccall $fn(15::Csize_t)::Any
    @test typeof(result) <: GenericMemory
    @test length(result) == 15
    println("@ccall version worked!")
    cif = Libffi.Ffi_cif(Any, (Csize_t,))
    result = Libffi.ffi_call(cif, fn, [Csize_t(15)])
    @test typeof(result) <: GenericMemory
    @test length(result) == 15

    cif = Libffi.Ffi_cif(Any, (Any,))
    fn = Libdl.dlsym(handle, :mwe_jl_alloc_genericmemory_jlarg)
    result = Libffi.ffi_call(cif, fn, [Memory{Int64}])
    @test typeof(result) === Memory{Int64}
    @test length(result) == 3

    # julia struct return type
    fn = Libdl.dlsym(handle, :mwe_my_type)
    cif = Libffi.Ffi_cif(my_type, (Cint,))
    result = Libffi.ffi_call(cif, fn, [Cint(123)])
    @test typeof(result) == my_type
    @test result.x == Cint(123)

    # call libjulia-internal:jl_alloc_genericmemory directly
    handle = Libdl.dlopen(Libdl.dlpath("libjulia-internal.so"))

    cif = Libffi.Ffi_cif(Any, (Any, Csize_t))
    fn = Libdl.dlsym(handle, :jl_alloc_genericmemory)
    result = Libffi.ffi_call(cif, fn, [Memory{Int64}, Csize_t(15)])
    @test typeof(result) <: GenericMemory
    @test length(result) == 15

    # test Cstring return types
    handle = Libdl.dlopen(Libdl.dlpath("libjulia.so"))

    cif = Libffi.Ffi_cif(Cstring, (Any,))
    fn = Libdl.dlsym(handle, :jl_typeof_str)
    x = FFI_MutDummy("sers", 12321)
    result = Libffi.ffi_call(cif, fn, [x])
    expected = "FFI_MutDummy"
    @test unsafe_string(result) == expected

    cif = Libffi.Ffi_cif(Cstring, (Any,))
    fn = Libdl.dlsym(handle, :jl_typeof_str)
    x = FFI_ImmutDummy("sers", 12321)
    result = Libffi.ffi_call(cif, fn, [x])
    expected = "FFI_ImmutDummy"
    @test unsafe_string(result) == expected

    # some of the ccall.jl tests
    handle = Libdl.dlopen(libccalltest)

    cif = Libffi.Ffi_cif(Ptr{Int64}, (Any,))
    fn = Libdl.dlsym(handle, :test_echo_p)
    result = Libffi.ffi_call(cif, fn, [1])
    expected = 1
    @test unsafe_load(result) == expected

    cif = Libffi.Ffi_cif(Ref{Int64}, (Any,))
    fn = Libdl.dlsym(handle, :test_echo_p)
    result = Libffi.ffi_call(cif, fn, [1])
    expected = 1
    @show result
end


@testset "runtime intrinsics" begin
    handle = Libdl.dlopen(Libdl.dlpath("libjulia-internal.so"))
    cif = Libffi.Ffi_cif(Ptr{Cvoid}, (Any, Any))
    fn = Libdl.dlsym(handle, :jl_bitcast)
    result = Libffi.ffi_call(cif, fn, [UInt, C_NULL])
    expected = C_NULL
    @test Libffi.unbox(Ptr{Cvoid}, result) == expected
end
