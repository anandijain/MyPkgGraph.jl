module MyPkgGraph

using AbstractTrees, Pkg
using Catlab, Catlab.Theories
using Catlab.CategoricalAlgebra
using Catlab.Theories
using Catlab.CategoricalAlgebra
using Catlab.Graphics
using Colors
import JSON, JSONSchema

using Graphs
import Graphs
using UUIDs
using DataFrames
using TOML

using Pkg.Registry: reachable_registries,
    uuids_from_name,
    init_package_info!,
    initialize_uncompressed!,
    JULIA_UUID

# a lot of this is stolen from https://github.com/tfiers/PkgGraph.jl. thanks! 
# function __init__()
REGISTRIES = Pkg.Registry.reachable_registries()
const GENERAL_REGISTRY = REGISTRIES[findfirst(reg.name == "General" for reg in REGISTRIES)]
# end

getd(d, xs) = map(x -> d[x], xs)
unzip(xs) = first.(xs), last.(xs)
function unzip(d::Dict)
    xs = collect(d)
    first.(xs), last.(xs)
end
sortl(xs) = sort(xs; by=last, rev=true)

stdlib() = begin
    packages = Dict{UUID,String}()
    for path in readdir(Sys.STDLIB; join=true)
        # ↪ `join` gets us complete paths
        if isdir(path)
            toml = proj_dict(path)
            push!(packages, UUID(toml["uuid"]) => toml["name"])
        end
    end
    packages
end
proj_dict(pkgdir) = TOML.parsefile(proj_file(pkgdir))
proj_file(pkgdir) = joinpath(pkgdir, "Project.toml")

const STDLIB = stdlib()
const STDLIB_UUIDS = collect(keys(STDLIB)) # i hate keyset 
const STDLIB_NAMES = collect(values(STDLIB))

direct_deps_of_stdlib_pkg(name) = begin
    pkgdir = joinpath(Sys.STDLIB, name)
    d = proj_dict(pkgdir)
    keys(get(d, "deps", []))
end

function name(r, uuid::UUID)
    if uuid in STDLIB_UUIDS
        STDLIB[uuid]
    elseif uuid in keys(r.pkgs)
        r.pkgs[uuid].name
    else
        error()
    end
end

name(uuid::UUID) = name(GENERAL_REGISTRY, uuid)

uuid(r, name::AbstractString) =
    if name in STDLIB_NAMES
        findfirst(==(name), STDLIB)
    else
        uuids = uuids_from_name(r, name)
        if isempty(uuids)
            error("Package `$name` not found")
        elseif length(uuids) > 1
            error("Multiple packages with the same name (`$name`) not supported")
        else
            return only(uuids)
        end
    end
uuid(name::AbstractString) = uuid(GENERAL_REGISTRY, name)

direct_deps_from_registry(r, pkg) = begin
    if pkg in STDLIB_NAMES
        return direct_deps_of_stdlib_pkg(pkg)
    end
    pkgentry = r.pkgs[uuid(r, pkg)]
    p = init_package_info!(pkgentry)
    versions = keys(p.version_info)
    v = maximum(versions)
    initialize_uncompressed!(p, [v])
    vinfo = p.version_info[v]
    compat_info = vinfo.uncompressed_compat
    # ↪ All direct deps will be here, even if author didn't them
    #   [compat] (their versionspec will just be "*").
    direct_dep_uuids = collect(keys(compat_info))
    filter!(!=(JULIA_UUID), direct_dep_uuids)
    ns = name.((r,), direct_dep_uuids)
    return ns
end

direct_deps_from_registry(pkg) = direct_deps_from_registry(GENERAL_REGISTRY, pkg)

function AbstractTrees.children(id::UUID)
    uuid.(direct_deps_from_registry(name(id)))
end
AbstractTrees.nodevalue(id::UUID) = name(id)

function AbstractTrees.children(r, id::UUID)
    uuid.((r,), direct_deps_from_registry(r, name(r, id)))
end
AbstractTrees.nodevalue(r, id::UUID) = name(r, id)

function bijection(a, b)
    Dict(a .=> b), Dict(b .=> a)
end

function indirect_deps(dg, x; dir=:in)
    elists = collect.(Pair.(collect(Graphs.edges(Graphs.bfs_tree(dg, x; dir)))))
    isempty(elists) ? [] : unique(stack(elists))
end
# indirect_dep_names(dg, x) = getd(md, indirect_deps(dg, x))

function pairs_to_df(ps)
    c1, c2 = unzip(ps)
    DataFrame(pkg=c1, indegree=c2)
end

@acset_type IndexedLabeledGraph(Catlab.Graphs.SchLabeledGraph, index=[:src, :tgt],
    unique_index=[:label]) <: Catlab.Graphs.AbstractLabeledGraph

function registry_graph(reg)
    Pkg.Registry.create_name_uuid_mapping!(reg)
    map(x -> Pkg.Registry.init_package_info!(last(x)), collect(reg.pkgs))
    pkgs = reg.pkgs
    pkgids_, pkgentries = MyPkgGraph.unzip(pkgs)

    pkgids = unique(vcat(pkgids_, collect(MyPkgGraph.STDLIB_UUIDS)))
    pkgnames = unique([MyPkgGraph.name.((reg,), pkgids_); MyPkgGraph.STDLIB_NAMES])
    NV = length(pkgids)
    id_vid = Dict(pkgids .=> 1:NV)

    did, rdi = MyPkgGraph.bijection(pkgids, pkgnames)
    g = IndexedLabeledGraph{String}()
    Catlab.Graphs.add_vertices!(g, NV; label=pkgnames)

    for (k, v) in did
        # @info k, v
        for c in children(reg, k)
            Catlab.Graphs.add_edge!(g, id_vid[k], id_vid[c])
        end
    end
    g
end
my_depgraph(g, pkg; dir=:out) = Catlab.Graphs.induced_subgraph(g, findall(!=(0), Graphs.degree(Graphs.bfs_tree(Graphs.DiGraph(g), Dict(reverse.(collect(g.subparts.label.m)))[pkg]; dir))))
my_depgraph(r::Pkg.Registry.RegistryInstance, pkg; dir=:out) = my_depgraph(registry_graph(r), pkg; dir)
my_depgraph(pkg; dir=:out) = my_depgraph(registry_graph(GENERAL_REGISTRY), pkg; dir)

export IndexedLabeledGraph, direct_deps_from_registry, GENERAL_REGISTRY, indirect_deps, registry_graph, my_depgraph
end # module MyPkgGraph
