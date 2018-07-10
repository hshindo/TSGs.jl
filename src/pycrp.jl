using Distributions

"""
    PYCRP

Chinese Restaurant Process based on Pitman-Yor process.

* d: a discount parameter (0 ≤ d < 1)
* θ: a strength parameter (θ > −d)
"""
mutable struct PYCRP
    basedist::Function
    d_prior::Beta
    θ_prior::Gamma
    d::Float64
    θ::Float64
    ntables::Int
    ncustomers::Int
    clusters::Dict
end

function PYCRP(basedist::Function)
    d_prior = Beta(1.0, 1.0)
    θ_prior = Gamma(1.0, 1.0)
    d = rand(d_prior) + 1e-10
    θ = rand(θ_prior) + 1e-10
    PYCRP(basedist, d_prior, θ_prior, d, θ, 0, 0, Dict{Int,CRPCluster}())
end

Base.getindex(pycrp::PYCRP, key::Int) = pycrp.clusters[key]

function add!(crp::PYCRP, x::Int, count=1)
    cl = get!(crp.clusters, x) do
        CRPCluster()
    end
    for i = 1:count
        newprob = (crp.θ + crp.d * crp.ntables) * crp.basedist(x)
        add!(cl,crp.d,newprob) && (crp.ntables += 1)
        crp.ncustomers += 1
    end
end

function remove!(crp::PYCRP, x::Int, count=1)
    cl = crp.clusters[x]
    @assert cl.ncustomers >= count
    for i = 1:count
        remove!(cl) && (crp.ntables -= 1)
        cl.ncustomers == 0 && delete!(crp.clusters,x)
        crp.ncustomers -= 1
    end
end

function update!(crp::PYCRP)
    crp.ncustomers == 0 && return
    function update_d(x)
        crp.d = x
        logpriorlikelihood(crp) + logpdf(crp.d_prior, x)
    end
    function update_θ(x)
        crp.θ = x
        logpriorlikelihood(crp) + logpdf(crp.θ_prior, x)
    end
    sampler_d = SliceSampler(update_d, crp.d, 0.0, 1.0)
    sampler_θ = SliceSampler(update_θ, crp.θ, 0.0, realmax(Float64))
    for i = 1:10
        crp.d = next!(sampler_d)
        crp.θ = next!(sampler_θ)
    end
    @assert 0.0 <= crp.d < 1.0
end

"""
Computes the log of generalized factorial function.

Generalized factorial: [a, b]_c = a(a+b)...(a+(c-1)b) = b^c * Γ(a/b+c) / Γ(a/b).
"""
function logfactorial(a::Float64, b::Float64, c::Int)
    if c <= 0
        0.0
    else
        c * log(b) + lgamma(a/b + c) - lgamma(a/b)
    end
end

function logpriorlikelihood(crp::PYCRP)
    newterm = logfactorial(crp.θ, crp.d, crp.ntables) - logfactorial(crp.θ, 1.0, crp.ncustomers)
    l = newterm
    for cl in values(crp.clusters)
        for c in cl.tablecounts
            l += logfactorial(1.0-crp.d, 1.0, c-1)
        end
    end
    l
end

function loglikelihood(crp::PYCRP)
    ll = logfactorial(crp.θ,crp.d,crp.ntables) - logfactorial(crp.θ,1.0,crp.ncustomers)
    for cl in values(crp.clusters)
        for c in cl.tablecounts
            ll += logfactorial(1.0-crp.d, 1.0, c-1)
        end
    end
    ll
end

function prob(crp::PYCRP, x::Int)
    p = 0.0
    if haskey(crp.clusters, x)
        cl = crp.clusters[x]
        p += (cl.ncustomers - crp.d * length(cl.tablecounts)) / (crp.θ + crp.ncustomers)
    end
    p += (crp.θ + crp.d * crp.ntables) * crp.basedist(x) / (crp.θ + crp.ncustomers)
    @assert p >= 0.0 && p < 1.00001
    p
end

mutable struct CRPCluster
    ncustomers::Int
    tablecounts::Vector{Int}
end
CRPCluster() = CRPCluster(0, Int[])

function add!(cl::CRPCluster, d::Float64, newprob::Float64)
    probs = map(c -> c-d, cl.tablecounts)
    push!(probs, newprob)
    i = sample(probs)
    cl.ncustomers += 1
    if i <= length(cl.tablecounts)
        cl.tablecounts[i] += 1
        false
    else
        push!(cl.tablecounts, 1)
        true
    end
end

function remove!(cl::CRPCluster)
    @assert cl.ncustomers > 0
    cl.ncustomers -= 1
    i = sample(map(Float64,cl.tablecounts))
    cl.tablecounts[i] -= 1
    if cl.tablecounts[i] == 0
        deleteat!(cl.tablecounts, i)
        true
    else
        false
    end
end

function sample(probs::Vector{Float64})
    @assert !isempty(probs)
    length(probs) == 1 && return 1

    r = rand() * sum(probs)
    total = 0.0
    for i = 1:length(probs)
        @assert probs[i] >= 0.0
        total += probs[i]
        total >= r && return i
    end
    throw("Something wrong.")
end
