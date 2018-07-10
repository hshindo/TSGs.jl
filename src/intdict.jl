using DataStructures

"""
    IntDict{T}

A dictionary for converting a key::T into an integer id.

## 👉 Example
```julia
dict = IntDict{String}()
push!(dict, "abc") == 1
push!(dict, "def") == 2
push!(dict, "abc") == 1

dict["abc"] == 1
getkey(dict, id1) == "abc"
```
"""
struct IntDict{T}
    key2id::Dict{T,Int}
    id2key::Vector{T}
    id2count::Vector{Int}
    openids::Queue{Int}
end
IntDict{T}() where T = IntDict(Dict{T,Int}(), T[], Int[], Queue(Int))

Base.count(dict::IntDict, id::Int) = dict.id2count[id]
Base.getindex(dict::IntDict, id::Int) = dict.id2key[id]
Base.getindex(dict::IntDict, key) = get(dict.key2id, key)
# Base.get(dict::IntDict, key) = get(dict.key2id, key, 0)
Base.length(dict::IntDict) = length(dict.key2id)
Base.keys(dict::IntDict) = keys(dict.key2id)
Base.values(dict::IntDict) = values(dict.key2id)

function add!(dict::IntDict{T}, key::T) where T
    if haskey(dict.key2id, key)
        id = dict.key2id[key]
        dict.id2count[id] += 1
    elseif length(dict.openids) > 0
        id = dequeue!(dict.openids)
        dict.key2id[key] = id
        dict.id2key[id] = key
        dict.id2count[id] = 1
    else
        id = length(dict.id2key) + 1
        dict.key2id[key] = id
        push!(dict.id2key, key)
        push!(dict.id2count, 1)
    end
    id
end
add!(dict::IntDict{T}, keys::Vector{T}) where T = map(k -> add!(dict,k), keys)

function remove!(dict::IntDict, id::Int)
    id2count = dict.id2count
    @assert id2count[id] > 0
    id2count[id] -= 1
    if id2count[id] == 0
        delete!(dict.key2id, dict[id])
        enqueue!(dict.openids, id)
    end
    id
end
