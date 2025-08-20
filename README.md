# Libffi.jl

This repository provides Julia bindings for (libffi)[https://github.com/libffi/libffi].

# Installation

```
julia> import Pkg
julia> Pkg.add("https://github.com/fatteneder/Libffi.jl")
```

# Usage

This repository provides an LLVM independent `@ccall` mechanism based on libffi.
You can use it as:

```julia
julia> import Libffi; Libdl

julia> libc = Libdl.dlopen("libc.so.6")

julia> p_clock = Libdl.dlsym(libc, :clock)

julia> cif = Libffi.Ffi_cif(Cint, ());

julia> Libffi.ffi_call(cif, p_clock, [])
22950370
```

# References

- (Julia lang docs on `ccall`)[https://docs.julialang.org/en/v1/manual/calling-c-and-fortran-code/]

# TODO

- Implement a version of `ffi_call` that caches `cfi`.
- Implement a `Libffi.@ccall` macro.
