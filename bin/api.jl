using MyPkgGraph, Oxygen, HTTP, Catlab, Catlab.Graphics, Catlab.Graphics.Graphviz, Graphs

g = registry_graph(MyPkgGraph.GENERAL_REGISTRY)
dg = Graphs.DiGraph(g)
m = g.subparts.label.m
il, li = MyPkgGraph.bijection(MyPkgGraph.unzip(collect(g.subparts.label.m))...)

@get "/deps/{pkg}" function precompile_resp(req, pkg)
    ig = my_depgraph(g, pkg)
    gv = to_graphviz(ig; node_labels=:label)
    io = IOBuffer()
    run_graphviz(io, gv, format="svg")
    HTTP.Response(200, ["Content-Type" => "image/svg+xml"]; body=take!(io))
end

@get "/invdeps/{pkg}" function precompile_resp(req, pkg)
    ig = my_depgraph(g, pkg; dir=:in)
    gv = to_graphviz(ig; node_labels=:label)
    io = IOBuffer()
    run_graphviz(io, gv, format="svg")
    HTTP.Response(200, ["Content-Type" => "image/svg+xml"]; body=take!(io))
end

@get "/bidir/{pkg}" function precompile_resp(req, pkg)
    ig = MyPkgGraph.bidir_depgraph(g, li[pkg])
    gv = to_graphviz(ig; node_labels=:label)
    io = IOBuffer()
    run_graphviz(io, gv, format="svg")
    HTTP.Response(200, ["Content-Type" => "image/svg+xml"]; body=take!(io))
end

serve()
