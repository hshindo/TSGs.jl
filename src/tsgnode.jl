import Base: ==

mutable struct TSGNode
    symid::Int
    cfgid::Int
    tsgid::Int
    fixed::Bool
end

issub(x::TSGNode) = x.tsgid > 0 # whether x is a substitution site or not
isfixed(x::TSGNode) = x.fixed

Base.copy(x::TSGNode) = TSGNode(x.symid, x.cfgid, x.tsgid, x.fixed)
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
            t = Tree(copy(s.data))
            # t = Tree(TSGNode(s.data.symid,s.data.cfgid,s.data.tsgid,s.data.fixed))
            push!(trg, t)
            issub(s.data) || _extract!(s,t)
        end
    end
    tsg = Tree(copy(tree.data))
    # tsg = Tree(TSGNode(tree.data.symid,tree.data.cfgid,tree.data.tsgid,tree.data.fixed))
    _extract!(tree, tsg)
    @assert !isleaf(tsg)
    tsg
end
