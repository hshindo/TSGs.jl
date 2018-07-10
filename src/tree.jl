import Base: ==

mutable struct Tree{T}
    data::T
    children::Vector{Tree{T}}
    parent
end

Tree(data::T, children::Tree{T}...) where T = Tree(data, Tree{T}[children...])
function Tree(data::T, children::Vector{Tree{T}}) where T
    t = Tree(data, children, nothing)
    for c in children
        c.parent = t
    end
    t
end
Base.getindex(tree::Tree, key::Int) = tree.children[key]
function Base.setindex!(tree::Tree, child::Tree, i::Int)
    tree.children[i] = child
    child.parent = tree
end
Base.endof(tree::Tree) = length(tree)
Base.isempty(tree::Tree) = isempty(tree.children)
Base.length(tree::Tree) = length(tree.children)
isroot(tree::Tree) = tree.parent == nothing
isleaf(tree::Tree) = isempty(tree.children)
function Base.push!(tree::Tree, children::Tree...)
    push!(tree.children, children...)
    for c in children
        c.parent = tree
    end
    tree
end
Base.append!(tree::Tree, children::Vector) = push!(tree, children...)
function Base.empty!(tree::Tree)
    for c in tree.children
        c.parent = nothing
    end
    empty!(tree.children)
    tree
end

"""
# of CFG rules
"""
function Base.size(tree::Tree)
    isleaf(tree) && return 0
    sum(size, tree.children) + 1
end

function Base.convert(f::Function, tree::Tree{T}) where T
    function _convert(src::Tree{T}, trg::Tree)
        for s in src.children
            t = Tree(f(s))
            push!(trg, t)
            _convert(s, t)
        end
    end
    res = Tree(f(tree))
    _convert(tree, res)
    res
end

function setchildren!(tree::Tree, children::Vector)
    empty!(tree)
    append!(tree, children)
end

function Base.hash(x::Tree)
    h = hash(x.data)
    for c in x.children
        h = hash(h, hash(c))
    end
    h
end
function ==(x::Tree{T}, y::Tree{T}) where T
    x.data == y.data || return false
    length(x) == length(y) || return false
    for i = 1:length(x)
        x[i] == y[i] || return false
    end
    return true
end

function remove(tree::Tree)
    i = findfirst(c -> c === tree, tree.parent.children)
    deleteat!(tree.parent.children, i)
    tree.parent = nothing
end

#=
function findall(f::Function, tree::Tree)
    nodes = Tree[]
    function traverse(node::Tree)
        f(node) && push!(nodes,node)
        for c in node.children
            traverse(c)
        end
    end
    traverse(tree)
    nodes
end
findall(tree::Tree, name::String) = findall(x -> x.name == name, tree)
=#

function topdown_while(f::Function, tree::Tree)
    cond = f(tree)
    @assert isa(cond,Bool)
    cond || return
    for c in tree.children
        topdown_while(f, c)
    end
end

function binarize_right!(tree::Tree{String})
    function _binarize!(node::Tree)
        length(node) <= 2 && return
        data = "_$(node.data)"
        n = node[end]
        for i = length(node)-1:-1:2
            n = Tree(data, [node[i],n])
        end
        setchildren!(node, [node[1],n])
        nothing
    end
    nodes = collect(bottomup(tree))
    foreach(_binarize!, nodes)
    tree
end

function Base.string(tree::Tree)
    strs = String["(", string(tree.data)]
    for c in tree.children
        push!(strs, string(c))
    end
    push!(strs, ")")
    join(strs)
end

function Base.parse(::Type{Tree}, sexpr::String)
    sexpr = strip(sexpr)
    @assert sexpr[1] == '(' && sexpr[end] == ')'
    sexpr = Vector{Char}(sexpr)
    function _parse(i::Int)
        chars = Char[]
        children = Tree{String}[]
        while i <= length(sexpr)
            c = sexpr[i]
            if c == '('
                child, i = _parse(i+1)
                push!(children, child)
            elseif c == ')'
                val = strip(join(chars))
                @assert !isempty(val)
                tree = Tree(val, children)
                return tree, i+1
            else
                push!(chars, sexpr[i])
                i += 1
            end
        end
        throw("Invalid S-expression.")
    end
    tree, _ = _parse(2)
    tree
end

struct TopdownTreeIterator
    tree::Tree
end
topdown(tree) = TopdownTreeIterator(tree)

Base.start(iter::TopdownTreeIterator) = [iter.tree]
Base.done(iter::TopdownTreeIterator, state::Vector) = isempty(state)
function Base.next(iter::TopdownTreeIterator, state::Vector)
    tree = pop!(state)
    for i = length(tree):-1:1
        push!(state, tree[i])
    end
    (tree, state)
end

struct BottomupTreeIterator
    nodes::Vector
end

function bottomup(tree::Tree{T}) where T
    nodes = Tree{T}[]
    function _bottomup(node::Tree)
        for c in node.children
            _bottomup(c)
        end
        push!(nodes, node)
    end
    _bottomup(tree)
    BottomupTreeIterator(nodes)
end

Base.start(iter::BottomupTreeIterator) = 1
Base.done(iter::BottomupTreeIterator, state::Int) = state > length(iter.nodes)
function Base.next(iter::BottomupTreeIterator, state::Int)
    (iter.nodes[state], state+1)
end
Base.length(iter::BottomupTreeIterator) = length(iter.nodes)
