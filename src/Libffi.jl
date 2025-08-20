module Libffi


import Libffi_jll
import Scratch
import TOML


const LIBFFIHELP_PATH = Ref{String}("")
const SCRATCH_DIR = Ref{String}("")
function __init__()
    project_file = joinpath(@__DIR__, "..", "Project.toml")
    project_toml = TOML.parsefile(project_file)
    uuid = Base.UUID(project_toml["uuid"])
    version = VersionNumber(project_toml["version"])
    SCRATCH_DIR[] = Scratch.get_scratch!(uuid, "Libffi-$(version)")
    LIBFFIHELP_PATH[] = normpath(joinpath(SCRATCH_DIR[], "libffihelp.so"))
    return
end


# @nospecialize is needed here to return the desired pointer also for immutables.
# IIUC without it jl_value_ptr will not see the immutable container and instead
# return a pointer to the first field in x.
#
# Consider this MWE:
# ```julia
# struct ImmutDummy
#   x
#   y
# end
#
# x = ImmutDummy("string", 1)
# p = @ccall jl_value_ptr(x::Any)::Ptr{Cvoid}
# p1 = value_pointer(x)
# p2 = value_pointer_without_nospecialize(x)
#
# GC.@preserve x begin
#   unsafe_string(@ccall jl_typeof_str(p::Ptr{Cvoid})::Cstring)  # "ImmutDummy"
#   unsafe_string(@ccall jl_typeof_str(p1::Ptr{Cvoid})::Cstring) # "ImmutDummy"
#   unsafe_string(@ccall jl_typeof_str(p2::Ptr{Cvoid})::Cstring) # segfaults in global scope,
#                                                                # but gives "ImmutDummy" inside
#                                                                # function
#end
# ```
# jl_value_ptr actually returns jl_value_t *, so we should be using a ::Any return type
# however, doing so would convert the returned value into a julia type
# using instead ::Ptr{Cvoid} we obtain an address that seems to be working with the rest
# FWIW this is also how its being used in code_typed outputs.
value_pointer(@nospecialize(x)) = @ccall jl_value_ptr(x::Any)::Ptr{Cvoid}

const Boxable = Union{Bool, Int8, Int16, Int32, Int64, UInt8, UInt32, UInt64, Float32, Float64, Ptr}
const Unboxable = Union{Bool, Int8, Int16, Int32, Int64, UInt8, UInt32, UInt64, Float32, Float64}
box(x::Bool) = @ccall jl_box_bool(x::Int8)::Ptr{Cvoid}
box(x::Int8) = @ccall jl_box_int8(x::Int8)::Ptr{Cvoid}
box(x::Int16) = @ccall jl_box_int16(x::Int16)::Ptr{Cvoid}
box(x::Int32) = @ccall jl_box_int32(x::Int32)::Ptr{Cvoid}
box(x::Int64) = @ccall jl_box_int64(x::Int64)::Ptr{Cvoid}
box(x::UInt8) = @ccall jl_box_uint8(x::UInt8)::Ptr{Cvoid}
box(x::UInt16) = @ccall jl_box_uint16(x::UInt16)::Ptr{Cvoid}
box(x::UInt32) = @ccall jl_box_uint32(x::UInt32)::Ptr{Cvoid}
box(x::UInt64) = @ccall jl_box_uint64(x::UInt64)::Ptr{Cvoid}
box(x::Float32) = @ccall jl_box_float32(x::Float32)::Ptr{Cvoid}
box(x::Float64) = @ccall jl_box_float64(x::Float64)::Ptr{Cvoid}
box(x::Ptr{UInt8}) = @ccall jl_box_uint8pointer(x::Ptr{UInt8})::Ptr{Cvoid}
box(x::Ptr{T}) where {T} = @ccall jl_box_voidpointer(x::Ptr{T})::Ptr{Cvoid}
unbox(::Type{Bool}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_bool(ptr::Ptr{Cvoid})::Bool
unbox(::Type{Int8}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_int8(ptr::Ptr{Cvoid})::Int8
unbox(::Type{Int16}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_int16(ptr::Ptr{Cvoid})::Int16
unbox(::Type{Int32}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_int32(ptr::Ptr{Cvoid})::Int32
unbox(::Type{Int64}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_int64(ptr::Ptr{Cvoid})::Int64
unbox(::Type{UInt8}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_uint8(ptr::Ptr{Cvoid})::UInt8
unbox(::Type{UInt16}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_uint16(ptr::Ptr{Cvoid})::UInt16
unbox(::Type{UInt32}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_uint32(ptr::Ptr{Cvoid})::UInt32
unbox(::Type{UInt64}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_uint64(ptr::Ptr{Cvoid})::UInt64
unbox(::Type{Float32}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_float32(ptr::Ptr{Cvoid})::Float32
unbox(::Type{Float64}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_float64(ptr::Ptr{Cvoid})::Float64
unbox(::Type{Ptr{UInt8}}, ptr::Ptr{Cvoid}) = @ccall jl_unbox_uint8pointer(ptr::Ptr{UInt8})::Ptr{UInt8}
unbox(::Type{Ptr{T}}, ptr::Ptr{Cvoid}) where {T} = @ccall jl_unbox_voidpointer(ptr::Ptr{Cvoid})::Ptr{T}


# libffi offers these types: https://www.chiark.greenend.org.uk/doc/libffi-dev/html/Primitive-Types.html
# ffi_type_void ffi_type_uint8 ffi_type_sint8 ffi_type_uint16 ffi_type_sint16 ffi_type_uint32
# ffi_type_sint32 ffi_type_uint64 ffi_type_sint64 ffi_type_float ffi_type_double ffi_type_uchar
# ffi_type_schar ffi_type_ushort ffi_type_sshort ffi_type_uint ffi_type_sint ffi_type_ulong
# ffi_type_slong ffi_type_longdouble ffi_type_pointer ffi_type_complex_float ffi_type_complex_double
# ffi_type_complex_longdouble
# ---
# julia offers these types: https://docs.julialang.org/en/v1/manual/calling-c-and-fortran-code/#man-bits-types
# Cvoid Cuchar Cshort Cushort Cint Cuint Clonglong Culonglong Cintmax_t Cuintmax_t Cfloat Cdouble
# ComplexF32 ComplexF64 Cptrdiff_t Cssize_t Csize_t Cchar Clong Culong Cwchar_t
# ---
# here we define a mapping between julia's native types and ffi's types
# this should be enough to automatically map the C type alias
ffi_type(p::Type{Cvoid}) = cglobal((:ffi_type_void, Libffi_jll.libffi), p)
ffi_type(p::Type{UInt8}) = cglobal((:ffi_type_uint8, Libffi_jll.libffi), p)
ffi_type(p::Type{Int8}) = cglobal((:ffi_type_sint8, Libffi_jll.libffi), p)
ffi_type(p::Type{UInt16}) = cglobal((:ffi_type_uint16, Libffi_jll.libffi), p)
ffi_type(p::Type{Int16}) = cglobal((:ffi_type_sint16, Libffi_jll.libffi), p)
ffi_type(p::Type{UInt32}) = cglobal((:ffi_type_uint32, Libffi_jll.libffi), p)
ffi_type(p::Type{Int32}) = cglobal((:ffi_type_sint32, Libffi_jll.libffi), p)
ffi_type(p::Type{UInt64}) = cglobal((:ffi_type_uint64, Libffi_jll.libffi), p)
ffi_type(p::Type{Int64}) = cglobal((:ffi_type_sint64, Libffi_jll.libffi), p)
ffi_type(p::Type{Float32}) = cglobal((:ffi_type_float, Libffi_jll.libffi), p)
ffi_type(p::Type{Float64}) = cglobal((:ffi_type_double, Libffi_jll.libffi), p)
ffi_type(p::Type{ComplexF32}) = cglobal((:ffi_type_complex_float, Libffi_jll.libffi), p)
ffi_type(p::Type{ComplexF64}) = cglobal((:ffi_type_complex_double, Libffi_jll.libffi), p)
ffi_type(p::Type{Cstring}) = cglobal((:ffi_type_pointer, Libffi_jll.libffi), p)
ffi_type(p::Type{Cwstring}) = ffi_type(Ptr{Cwchar_t})
ffi_type(@nospecialize(p::Type{Ptr{T}})) where {T} = cglobal((:ffi_type_pointer, Libffi_jll.libffi), p)
ffi_type(@nospecialize(t)) = (isconcretetype(t)) ? ffi_type_struct(t) : ffi_type(Ptr{Cvoid})
# Note for AArch64 (from julia/src/ccalltests.c)
# `i128` is a native type on aarch64 so the type here is wrong.
# However, it happens to have the same calling convention with `[2 x i64]`
# when used as first argument or return value.
struct MimicInt128
    x::Int64
    y::Int64
end
ffi_type(p::Type{Int128}) = ffi_type_struct(MimicInt128)
ffi_type(p::Type{String}) = ffi_type(Ptr{Cvoid})
ffi_type(@nospecialize(p::Type{<:Array})) = ffi_type(fieldtype(p, :ref))
ffi_type(@nospecialize(p::Type{<:GenericMemoryRef{<:Any, T, Core.CPU}})) where {T} = ffi_type(Ptr{T})

# wrappers for libffihelper.so
ffi_default_abi() = @ccall LIBFFIHELP_PATH[].ffi_default_abi()::Cint
sizeof_ffi_cif() = @ccall LIBFFIHELP_PATH[].sizeof_ffi_cif()::Csize_t
sizeof_ffi_arg() = @ccall LIBFFIHELP_PATH[].sizeof_ffi_arg()::Csize_t
sizeof_ffi_type() = @ccall LIBFFIHELP_PATH[].sizeof_ffi_type()::Csize_t
ffi_sizeof(p::Ptr) = @ccall LIBFFIHELP_PATH[].get_size_ffi_type(p::Ptr{Cvoid})::Csize_t

function ffi_sizeof_rettyp(ty::Type)
    return Csize_t(!(ty <: Boxable) && isconcretetype(ty) ? sizeof(ty) : sizeof_ffi_arg())
end
ffi_sizeof_rettyp(ty::Type{<:Ref}) = ffi_sizeof_rettyp(Any)

function ffi_sizeof_argtype(ty::Type)
    return Csize_t(!(ty <: Boxable) && isconcretetype(ty) ? sizeof(ty) : sizeof_ffi_arg())
end

const Ctypes = Union{
    Cchar, Cuchar, Cshort, Cstring, Cushort, Cint, Cuint, Clong, Culong,
    Clonglong, Culonglong, Cintmax_t, Cuintmax_t, Csize_t, Cssize_t,
    Cptrdiff_t, Cwchar_t, Cwstring, Cfloat, Cdouble, Cvoid,
}

to_c_type(t::Ctypes) = t
to_c_type(t) = Ptr{Cvoid}

struct TypeCache
    mem_ffi_type::Vector{UInt8}
    elements::Vector{Ptr{Cvoid}}
end

const FFI_TYPE_CACHE = Dict{Type, TypeCache}()
function ffi_type_struct(@nospecialize(t::Type{T})) where {T}
    cache = get(FFI_TYPE_CACHE, T, nothing)
    if !isnothing(cache)
        return pointer(cache.mem_ffi_type)
    end
    n = fieldcount(T)
    elements = Vector{Ptr{Cvoid}}(undef, n + 1) # +1 for null terminator
    for i in 1:n
        elements[i] = ffi_type(fieldtype(T, i))
    end
    elements[end] = C_NULL
    mem_ffi_type = Vector{UInt8}(undef, sizeof_ffi_type())
    @ccall LIBFFIHELP_PATH[].setup_ffi_type_struct(
        mem_ffi_type::Ref{UInt8},
        elements::Ref{Ptr{Cvoid}}
    )::Cvoid
    ffi_offsets = Vector{Csize_t}(undef, n)
    default_abi = ffi_default_abi()
    status = @ccall Libffi_jll.libffi_path.ffi_get_struct_offsets(
        default_abi::Cint,
        mem_ffi_type::Ref{UInt8}, ffi_offsets::Ref{Csize_t}
    )::Cint
    if status != 0
        msg = "Failed to setup a ffi struct type for $T; ffi_get_struct_offsets returned status "
        if status == 1
            error(msg * "FFI_BAD_TYPEDEF")
        elseif status == 2
            error(msg * "FFI_BAD_ABI")
        elseif status == 3
            error(msg * "FFI_BAD_ARGTYPE")
        else
            error(msg * "unknown error code $status")
        end
    end
    if any(i -> ffi_offsets[i] != Csize_t(fieldoffset(T, i)), 1:n)
        jl_offsets = [ fieldoffset(T, i) for i in 1:n ]
        jl_types = [ fieldtype(T, i) for i in 1:n ]
        error(
            """Mismatch in field offsets of type $T
               Field types: $(join(jl_types, ", "))
               Offsets:
                   Julia:  $(join(jl_offsets, ", "))
                   libffi: $(join(Int64.(ffi_offsets), ", "))
            """
        )
    end
    FFI_TYPE_CACHE[T] = TypeCache(mem_ffi_type, elements)
    return pointer(mem_ffi_type)
end

# TODO cache results by signature,
public Ffi_cif
mutable struct Ffi_cif
    mem::Vector{UInt8}
    rettype::Type
    argtypes::Vector{Type}
    ffi_rettype::Ptr{Cvoid}
    ffi_argtypes::Vector{Ptr{Cvoid}}

    function Ffi_cif(@nospecialize(rettype::Type{T}), @nospecialize(argtypes::NTuple{N})) where {T, N}
        if !isconcretetype(T) && T !== Any && !(T <: Ref)
            throw(
                ArgumentError(
                    "$T is an invalid return type, " *
                        "see the @ccall return type translation guide in the manual"
                )
            )
        end
        if T <: Ref && !(T <: Ptr) && !isconcretetype(eltype(T))
            throw(
                ArgumentError(
                    "$T is an invalid return type, " *
                        "see the @ccall return type translation guide in the manual"
                )
            )
        end
        ffi_rettype = ffi_type(T)
        if any(a -> a === Cvoid, argtypes)
            throw(ArgumentError("Encountered bad argument type Cvoid"))
        end
        ffi_argtypes = N == 0 ? C_NULL : Ptr{Cvoid}[ ffi_type(at) for at in argtypes ]
        sz_cif = sizeof_ffi_cif()
        @assert sz_cif > 0
        mem_cif = Vector{UInt8}(undef, sizeof(UInt8) * sz_cif)
        p_cif = pointer(mem_cif)
        default_abi = ffi_default_abi()
        status = @ccall Libffi_jll.libffi_path.ffi_prep_cif(
            p_cif::Ptr{Cvoid}, default_abi::Cint, N::Cint,
            ffi_rettype::Ptr{Cvoid}, ffi_argtypes::Ptr{Ptr{Cvoid}}
        )::Cint
        if status == 0 # = FFI_OK
            slots = Vector{Ptr{Cvoid}}(undef, 2 * N)
            return new(
                mem_cif, T, [ a for a in argtypes ],
                ffi_rettype, N == 0 ? Ptr{Cvoid}[] : ffi_argtypes
            )
        else
            msg = "Failed to prepare ffi_cif for f(::$(join(argtypes, ",::")))::$T; ffi_prep_cif returned status "
            if status == 1
                error(msg * "FFI_BAD_TYPEDEF")
            elseif status == 2
                error(msg * "FFI_BAD_ABI")
            elseif status == 3
                error(msg * "FFI_BAD_ARGTYPE")
            else
                error(msg * "unknown error code $status")
            end
        end
    end
end

public ffi_call
function ffi_call(cif::Ffi_cif, fn::Ptr{Cvoid}, @nospecialize(args::Vector))
    if fn === C_NULL
        throw(ArgumentError("Function ptr can't be NULL"))
    end
    N = length(cif.argtypes)
    if N != length(args)
        throw(
            ArgumentError(
                "Number of arguments must match with the Ffi_cif's defintion, " *
                    "found $(length(args)) vs $N"
            )
        )
    end

    # return value memory
    sz_ret = if cif.rettype <: Ctypes || cif.rettype === Any || cif.rettype <: Ref
        sizeof_ffi_arg()
    else # its a concrete type and fn returns-by-copy
        ffi_sizeof(cif.ffi_rettype)
    end
    mem_ret = zeros(UInt8, sz_ret)

    # slots memory
    mem_args = Vector{UInt8}[]
    N = length(cif.argtypes)
    slots = Vector{Ptr{Cvoid}}(undef, 2 * N) # overestimated, as not all args require indirection
    for (i, a) in enumerate(args)
        if a isa Boxable
            if cif.argtypes[i] === Any
                # jl_value_t *
                slots[N + i] = box(a)
                slots[i] = pointer(slots, N + i)
            else
                # isbitstype
                slots[i] = box(a)
            end
        elseif cif.argtypes[i] <: Ref
            slots[i] = value_pointer(a)
        elseif isconcretetype(cif.argtypes[i])
            mem = zeros(UInt8, sizeof(cif.argtypes[i]))
            push!(mem_args, mem)
            GC.@preserve mem a begin
                unsafe_copyto!(pointer(mem), Ptr{UInt8}(value_pointer(a)), sizeof(a))
            end
            slots[i] = pointer(mem)
        else
            slots[N + i] = value_pointer(a)
            slots[i] = pointer(slots, N + i)
        end
    end

    # TODO Assume that caller preserves args!!!
    GC.@preserve cif args slots mem_args mem_ret begin
        p = Ptr{Cvoid}(pointer(cif.mem))
        @ccall Libffi_jll.libffi_path.ffi_call(
            p::Ptr{Cvoid}, fn::Ptr{Cvoid},
            mem_ret::Ptr{Cvoid}, slots::Ptr{Ptr{Cvoid}}
        )::Cvoid
        return if isbitstype(cif.rettype)
            @ccall jl_new_bits(cif.rettype::Any, mem_ret::Ptr{Cvoid})::Any
        elseif cif.rettype === Any || cif.rettype <: Ref
            unsafe_pointer_to_objref(unsafe_load(Ptr{Ptr{Cvoid}}(pointer(mem_ret))))
        else
            unsafe_load(Ptr{cif.rettype}(pointer(mem_ret)))
        end
    end
end


end # module Libffi
