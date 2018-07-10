export Trainer
export gibbs!, output
import ProgressMeter: ProgressMeter, Progress

mutable struct Trainer
    config::Dict
    trees::Vector{Tree{TSGNode}}
    symdict::IntDict
    cfgdict::IntDict
    tsgdict::IntDict
    tsgdists::Vector{PYCRP}    # nonterm -> PYCRP
    cfgprobs::Vector{Float64}  # CFG id -> cfg prob
    stopprobs::Vector{Float64}  # nonterm -> stop prob
end

function Trainer(config::Dict)
    lines = open(readlines, config["input_file"])
    trees = map(lines) do line
        tree = parse(Tree, line)
        binarize_right!(tree)
    end

    # node symbol -> id
    symdict = IntDict{String}()
    for tree in trees
        for n in topdown(tree)
            isleaf(n) || add!(symdict,n.data)
        end
    end
    nonterm_count = length(symdict)
    trees = map(trees) do tree
        convert(tree) do n
            symid = add!(symdict, n.data)
            TSGNode(symid, -1, -1)
        end
    end

    # Initialize CFG and TSG
    cfgdict = IntDict{Tree{Int}}()
    tsgdict = IntDict{Tree{TSGNode}}()
    for tree in trees
        for n in bottomup(tree)
            isleaf(n) && continue
            n.data.cfgid = add!(cfgdict, extract_cfg(n))
            if isroot(n) || rand() >= 0.5
                n.data.tsgid = add!(tsgdict, extract_tsg(n))
            end
        end
    end

    term_count = length(symdict) - nonterm_count
    println("# Trees:\t$(length(trees))")
    println("# NonTerminal:\t$(nonterm_count)")
    println("# Terminal:\t$(term_count)")
    println("# CFG rules:\t$(length(cfgdict))")
    println("# TSG rules:\t$(length(tsgdict))")

    # Calculate probabilities
    cfg_counts = zeros(Int, nonterm_count)
    for id in values(cfgdict)
        rootid = cfgdict[id].data
        cfg_counts[rootid] += count(cfgdict, id)
    end
    cfgprobs = Array{Float64}(length(cfgdict))
    for id in values(cfgdict)
        rootid = cfgdict[id].data
        cfgprobs[id] = count(cfgdict,id) / cfg_counts[rootid]
    end
    stopprobs = fill(0.5, nonterm_count)
    tsgdists = [PYCRP(x -> baseprob(tsgdict[x],cfgprobs,stopprobs)) for _=1:nonterm_count]
    for id in values(tsgdict)
        tsg = tsgdict[id]
        dist = tsgdists[tsg.data.symid]
        add!(dist, id, count(tsgdict,id))
    end

    Trainer(config, trees, symdict, cfgdict, tsgdict, tsgdists, cfgprobs, stopprobs)
end

function baseprob(tsg::Tree, cfgprobs::Vector{Float64}, stopprobs::Vector{Float64})
    p = 1.0
    for n in topdown(tsg)
        symid, cfgid = n.data.symid, n.data.cfgid
        if isleaf(n)
            symid <= length(stopprobs) && (p *= stopprobs[symid])
        else
            bp = cfgprobs[cfgid]
            if isroot(n)
                p *= bp
            else
                p *= bp
                p *= 1.0 - stopprobs[symid]
            end
        end
    end
    @assert p >= 0.0 && p <= 1.00001
    min(1.0, p)
end

"""
TSG induction with Gibbs sampling
"""
function gibbs!(trainer::Trainer)
    config = trainer.config
    nodes = Tree{TSGNode}[]
    for tree in trainer.trees
        for n in topdown(tree)
            isroot(n) || isleaf(n) || push!(nodes,n)
        end
    end
    println("# Sample nodes:\t$(length(nodes))")

    for epoch = 1:config["nepochs"]
        println("Epoch:\t$epoch")
        prog = Progress(length(nodes))
        shuffle!(nodes)
        for node in nodes
            sample!(trainer, node)
            ProgressMeter.next!(prog)
        end
        update!(trainer)

        likelihood = sum(loglikelihood, trainer.tsgdists)
        println("Likelihood:\t$likelihood")
        println("# TSG rules\t$(length(trainer.tsgdict))")
        m = mean(size, keys(trainer.tsgdict))
        println("Mean of TSG size\t$m")
        println()
    end
end

function sample!(trainer::Trainer, target::Tree{TSGNode})
    parent = target.parent
    while true
        issub(parent.data) && break
        parent = parent.parent
    end

    tsgdict = trainer.tsgdict
    tsgids1 = map(n -> n.data.tsgid, (parent,target))
    for id in tsgids1
        id <= 0 && continue
        tsg = tsgdict[id]
        dist = trainer.tsgdists[tsg.data.symid]
        remove!(dist, id)
    end

    # flip substitution
    if issub(target.data)
        target.data.tsgid = 0
        parent.data.tsgid = add!(tsgdict, extract_tsg(parent))
    else
        target.data.tsgid = add!(tsgdict, extract_tsg(target))
        parent.data.tsgid = add!(tsgdict, extract_tsg(parent))
    end
    tsgids2 = map(n -> n.data.tsgid, (parent,target))

    p1 = 1.0
    for id in tsgids1
        id <= 0 && continue
        tsg = tsgdict[id]
        dist = trainer.tsgdists[tsg.data.symid]
        p1 *= prob(dist, id)
    end
    p2 = 1.0
    for id in tsgids2
        id <= 0 && continue
        tsg = tsgdict[id]
        dist = trainer.tsgdists[tsg.data.symid]
        p2 *= prob(dist, id)
    end

    if rand()*(p1+p2) >= p1
        tsgids1, tsgids2 = tsgids2, tsgids1
    end

    for id in tsgids1
        id <= 0 && continue
        tsg = tsgdict[id]
        dist = trainer.tsgdists[tsg.data.symid]
        add!(dist, id)
    end
    for id in tsgids2
        id <= 0 && continue
        remove!(tsgdict, id)
    end
    parent.data.tsgid = tsgids1[1]
    target.data.tsgid = tsgids1[2]
end

function update!(trainer::Trainer)
    foreach(update!, trainer.tsgdists)

    nonterm_count = length(trainer.tsgdists)
    stop_counts = ones(Int, nonterm_count)
    nonstop_counts = ones(Int, nonterm_count)
    for id in values(trainer.tsgdict)
        tsg = trainer.tsgdict[id]
        dist = trainer.tsgdists[tsg.data.symid]
        ntables = length(dist[id].tablecounts)
        for n in topdown(tsg)
            symid = n.data.symid
            symid >= nonterm_count && continue # skip terminal nodes
            if isleaf(n)
                stop_counts[symid] += ntables
            else
                nonstop_counts[symid] += ntables
            end
        end
    end
    for i = 1:nonterm_count
        trainer.stopprobs[i] = stop_counts[i] / (stop_counts[i]+nonstop_counts[i])
    end
end

function output(trainer::Trainer)
    tsgdict = trainer.tsgdict
    data = Tuple{String,Int}[]
    for id in values(tsgdict)
        tsg = tsgdict[id]
        tsg = convert(tsg) do n
            s = trainer.symdict[n.data.symid]
            isleaf(n) ? s : "@"*s # add @ for nonterminal node
        end
        s = string(tsg)
        c = count(tsgdict, id)
        push!(data, (s,c))
    end
    sort!(data, by=x->x[2], rev=true)

    outfile = trainer.config["output_file"]
    println("Writing $outfile...")
    open(outfile, "w") do io
        for (s,c) in data
            println(io, "$s\t$c")
        end
    end
end