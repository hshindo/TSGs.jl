include("../src/tree.jl")

"""
read PTB .mrg file, format and write
"""
function collect_mrg()
    path = "C:/Users/hshindo/Dropbox/corpus/wsj"
    sexprs = []
    for file in readdir(path)
        f = joinpath(path, file)
        temp = []
        for line in open(readlines,f)
            isempty(line) && continue
            if line[1] == '('
                isempty(temp) || push!(sexprs,join(temp))
                temp = []
                chars = Vector{Char}(line)
                insert!(chars, 2, 'T')
                insert!(chars, 3, 'O')
                insert!(chars, 4, 'P')
                line = join(chars)
            else
                line = strip(line)
            end
            push!(temp, line)
        end
        isempty(temp) || push!(sexprs,join(temp))
    end
    strs = []
    for sexpr in sexprs
        tree = parse(Tree, sexpr)

        # split POS and word
        leaves = Tree[]
        topdown(tree) do n
            isempty(n) && push!(leaves,n)
        end
        for n in leaves
            items = collect(split(n.data,' '))
            @assert length(items) == 2
            n.data = strip(items[1])
            push!(n, Tree(strip(items[2])))
        end

        # remove -NONE-
        nodes = Tree[]
        topdown(tree) do n
            n.data == "-NONE-" && push!(nodes,n)
        end
        for n in nodes
            while n.data == "-NONE-" || isempty(n)
                p = n.parent
                remove(n)
                n = p
            end
        end
        push!(strs, string(tree))
    end
    open("a.mrg", "w") do io
        for s in strs
            println(io, s)
        end
    end
end
collect_mrg()
