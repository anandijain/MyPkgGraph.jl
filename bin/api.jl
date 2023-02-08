using MyPkgGraph, Oxygen, HTTP, Catlab, Catlab.Graphics, Catlab.Graphics.Graphviz, Graphs

g = registry_graph(MyPkgGraph.GENERAL_REGISTRY)
dg = Graphs.DiGraph(g)
m = g.subparts.label.m
md = Dict(m)
d = Dict(reverse.(collect(m)))

@get "/deps/{pkg}" function precompile_resp(req, pkg)
    bfs = Graphs.bfs_tree(dg, d[pkg]; dir=:out)
    ig = Catlab.Graphs.induced_subgraph(g, findall(!=(0), Graphs.degree(bfs)))
    gv = to_graphviz(ig; node_labels=:label)
    io = IOBuffer()
    run_graphviz(io, gv, format="svg")
    HTTP.Response(200, ["Content-Type" => "image/svg+xml"]; body=take!(io))
end

@get "/invdeps/{pkg}" function precompile_resp(req, pkg)
    bfs = Graphs.bfs_tree(dg, d[pkg]; dir=:in)
    ig = Catlab.Graphs.induced_subgraph(g, findall(!=(0), Graphs.degree(bfs)))
    gv = to_graphviz(ig; node_labels=:label)
    io = IOBuffer()
    run_graphviz(io, gv, format="svg")
    HTTP.Response(200, ["Content-Type" => "image/svg+xml"]; body=take!(io))
end

serve()
