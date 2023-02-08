using AbstractTrees, Pkg
using Catlab, Catlab.Theories
using Catlab.CategoricalAlgebra
using Catlab.Graphs
# import Catlab: Graphs
# import Catlab.Graphs: Graph
using Catlab, Catlab.Theories
using Catlab.CategoricalAlgebra
using Catlab.Graphics
using Colors
import JSON, JSONSchema

using Catlab, Catlab.Theories, Catlab.Graphs, Catlab.CategoricalAlgebra
using Catlab.Graphics
using Graphs

using UUIDs
using DataFrames
using TOML

using Pkg.Registry: reachable_registries,
    uuids_from_name,
    init_package_info!,
    initialize_uncompressed!,
    JULIA_UUID
using Test
using MyPkgGraph

# this test will break soon
@test length(children(MyPkgGraph.uuid("Catlab"))) == 20
direct_deps_from_registry("Catlab")
ls = collect(Leaves(MyPkgGraph.uuid("Catlab")))
uls = unique(ls)

MyPkgGraph.uuid("LinearAlgebra")

pkgs = GENERAL_REGISTRY.pkgs
pkgids_, pkgentries = MyPkgGraph.unzip(pkgs);

pkgids = unique(vcat(pkgids_, collect(MyPkgGraph.STDLIB_UUIDS)))
pkgnames = unique([MyPkgGraph.name.(pkgids_); MyPkgGraph.STDLIB_NAMES])

g = registry_graph(GENERAL_REGISTRY)

# private packages can have public deps, and wouldn't be found
# @test_throws Any registry_graph(MyPkgGraph.REGISTRIES[2])

# open("graph.json", "w") do f
#     JSON.print(f, generate_json_acset(g), 2)
# end

m = g.subparts.label.m
md = Dict(m)
d = Dict(reverse.(collect(m)))

dg = Graphs.SimpleDiGraph(g) # amazing that this works so nicely 
bfs = Graphs.bfs_tree(dg, d["Catlab"]; dir=:in)
ccs = Graphs.connected_components(dg)
dgi = dg[ccs[1]] # induced subgraph 
ccn = MyPkgGraph.getd.((md,), ccs)
pkgs[MyPkgGraph.uuid("FunctionBarrier")].info.repo

# sort by direct dependencies 
os = MyPkgGraph.sortl(pkgnames .=> Graphs.outdegree(dg))
# plot(last.(os))

# sort by direct dependents 
is = MyPkgGraph.sortl(pkgnames .=> Graphs.indegree(dg))
# plot(last.(is))

# plot(last.(os) ./ last.(is))

#pkg dependents 
sort(MyPkgGraph.getd(md, Graphs.inneighbors(dg, d["Pkg"])))

c1, c2 = MyPkgGraph.unzip(is)
df = DataFrame(pkg=c1, indegree=c2)
# CSV.write("indegree.csv", df)
jlls = filter(x -> contains(x.pkg, "_jll"), df)


# total dependants
id = d["LinearAlgebra"]
linalg = Graphs.bfs_tree(dg, id; dir=:in)
@assert Graphs.nv(linalg) == Graphs.nv(dg)
es = collect(Graphs.edges(linalg))
unique(reduce(vcat, collect.(Pair.(es))))


linalg = Graphs.bfs_tree(dg, d["Distributions"]; dir=:in)
@assert Graphs.nv(linalg) == Graphs.nv(dg)
es = collect(Graphs.edges(linalg))
MyPkgGraph.getd(md, unique(reduce(vcat, collect.(Pair.(es)))))

direct_deps_from_registry("CompilerSupportLibraries_jll")

function depgraph_df(g)
    m = g.subparts.label.m
    md = Dict(m)
    d = Dict(reverse.(collect(m)))

    dg = Graphs.SimpleDiGraph(g) # amazing that this works so nicely 

    ps = []
    for x in c1
        push!(ps, x => Graphs.ne(Graphs.bfs_tree(dg, d[x]; dir=:in)))
    end

    df[!, :id] = MyPkgGraph.getd(d, df.pkg)
    df[!, :indegree] = Graphs.indegree.((dg,), df.id)
    df[!, :outdegree] = Graphs.outdegree.((dg,), df.id)
    df[!, :indirect_deps] = indirect_deps.((dg,), df.id)
    df[!, :total_dependencies] = length.(map(x -> MyPkgGraph.indirect_deps(dg, x; dir=:out), df.id))
    df[!, :total_dependents] = length.(df.indirect_deps)
    df.inoutratio = df.indegree ./ df.outdegree
    df.total_inoutratio = df.total_dependents ./ df.total_dependencies
    df 
end

df = depgraph_df(g)
df_ = deepcopy(df)
df = df[:, Not(:indirect_deps)]
sort!(df, :total_dependents, rev=true)

filter(x -> !isnan(x.inoutratio) && x.inoutratio != Inf, df)
df_ = deepcopy(df)
filter!(x -> !isnan(x.inoutratio) && x.inoutratio != Inf, df)
filter!(x -> x.pkg ∉ MyPkgGraph.STDLIB_NAMES, df)
sort!(df, :inoutratio, rev=true)

df[:, :prod] = df.indegree .* df.outdegree
df[:, :total_prod] = df.total_dependents .* df.total_dependencies
sort!(df, :total_prod, rev=true)
# CSV.write("total.csv", df)

@time registry_graph(GENERAL_REGISTRY)
@time to_graphviz(MyPkgGraph.my_depgraph(GENERAL_REGISTRY, "DifferentialEquations"); node_labels=:label)
@time to_graphviz(MyPkgGraph.my_depgraph(GENERAL_REGISTRY, "DifferentialEquations"); node_labels=:label)
@time to_graphviz(MyPkgGraph.my_depgraph(GENERAL_REGISTRY, "ModelingToolkit"); node_labels=:label)
@time to_graphviz(MyPkgGraph.my_depgraph(GENERAL_REGISTRY, "DiffEqBase"); node_labels=:label)
@time to_graphviz(MyPkgGraph.my_depgraph(GENERAL_REGISTRY, "DifferentialEquations"; dir=:in); node_labels=:label)

to_graphviz(MyPkgGraph.my_depgraph(GENERAL_REGISTRY, "ReactionSensitivity"); node_labels=:label)
draw(r, s; dir=:out) = to_graphviz(MyPkgGraph.my_depgraph(r, s; dir); node_labels=:label)
draw(s; dir=:out) = draw(GENERAL_REGISTRY, s; dir)

@time to_graphviz(MyPkgGraph.my_depgraph(GENERAL_REGISTRY, "ModelingToolkit"; dir=:in); node_labels=:label)
url(s) = GENERAL_REGISTRY.pkgs[MyPkgGraph.uuid(s)].info.repo

to_graphviz(MyPkgGraph.my_depgraph(GENERAL_REGISTRY, "Plots"; dir=:out); node_labels=:label)
to_graphviz(MyPkgGraph.my_depgraph("Plots"; dir=:out); node_labels=:label)
to_graphviz(MyPkgGraph.my_depgraph("GLMakie"; dir=:out); node_labels=:label)

# stdlib graph
g = registry_graph()
il, li = MyPkgGraph.bijection(MyPkgGraph.unzip(collect(g.subparts.label.m))...)
stdlib_vids = MyPkgGraph.getd(li, MyPkgGraph.STDLIB_NAMES)
sg = Catlab.Graphs.induced_subgraph(g, stdlib_vids)
to_graphviz(sg; node_labels=:label)

# top level stdlibs
sg[setdiff(Catlab.Graphs.vertices(sg), unique(last.(collect(sg.subparts.tgt.m)))), :label]

# bidir_depgraph
bg = MyPkgGraph.bidir_depgraph(g, li["Plots"])
to_graphviz(bg; node_labels=:label)
