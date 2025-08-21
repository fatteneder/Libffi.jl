import Clang_jll
import Libffi_jll
import Scratch
import TOML

project_file = joinpath(@__DIR__, "..", "Project.toml")
project_toml = TOML.parsefile(project_file)
uuid = Base.UUID(project_toml["uuid"])
version = VersionNumber(project_toml["version"])
scratch_dir = Scratch.get_scratch!(uuid, "Libffi-$(version)")

vendored_julia_dir = joinpath(Sys.BINDIR, "..")
julia_include = joinpath(vendored_julia_dir, "include")
julia_lib = joinpath(vendored_julia_dir, "lib")
libffi_include = joinpath(Libffi_jll.artifact_dir, "include")
libffi_lib = joinpath(Libffi_jll.artifact_dir, "lib")

clang = Clang_jll.clang()

src = joinpath(@__DIR__, "libffihelp.c")
so = joinpath(scratch_dir, "libffihelp.so")
run(`$(clang)
     $(src)
     -I$(libffi_include)
     -L$(libffi_lib)
     -std=gnu11 -fPIC -lffi -shared
     -o $(so)
     `)

src = joinpath(@__DIR__, "libccalltest.c")
so = joinpath(scratch_dir, "libccalltest.so")
run(`$(clang)
     $(src)
     -I$(julia_include) -I$(julia_include)/julia -I$(@__DIR__)
     -L$(julia_lib) -L$(julia_lib)/julia
     -Wl,--export-dynamic -Wl,-rpath,$(julia_lib) -Wl,-rpath,$(julia_lib)/julia
     -std=gnu11 -fPIC -ljulia -ljulia-internal -shared
     -o $(so)`)

src = joinpath(@__DIR__, "libmwes.c")
so = joinpath(scratch_dir, "libmwes.so")
run(`$(clang)
     $(src)
     -I$(julia_include) -I$(julia_include)/julia -I$(@__DIR__)
     -L$(julia_lib) -L$(julia_lib)/julia
     -Wl,--export-dynamic -Wl,-rpath,$(julia_lib) -Wl,-rpath,$(julia_lib)/julia
     -std=gnu11 -fPIC -ljulia -ljulia-internal -shared
     -O3
     -o $(so)`)

println("done")
