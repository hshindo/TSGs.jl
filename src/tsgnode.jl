import Base: ==

mutable struct TSGNode
    symid::Int
    cfgid::Int
    tsgid::Int
end

issub(x::TSGNode) = x.tsgid > 0 # whether x is a substitution site or not

Base.hash(x::TSGNode) = hash(x.symid)
==(x::TSGNode, y::TSGNode) = x.symid == y.symid

function extract_cfg(tree::Tree{TSGNode})
    children = map(x -> Tree(x.data.symid), tree.children)
    Tree(tree.data.symid, children)
end

function extract_tsg(tree::Tree{TSGNode})
    @assert !isleaf(tree)
    function _extract!(src::Tree{TSGNode}, trg::Tree{TSGNode})
        for s in src.children
            t = Tree(TSGNode(s.data.symid,s.data.cfgid,s.data.tsgid))
            push!(trg, t)
            issub(s.data) || _extract!(s,t)
        end
    end
    tsg = Tree(TSGNode(tree.data.symid,tree.data.cfgid,tree.data.tsgid))
    _extract!(tree, tsg)
    @assert !isleaf(tsg)
    tsg
end
