# TSGs
Tree Substitution Grammars

## Install
First, install [Julia](https://julialang.org/) 0.6.x.
Then,
```
julia> Pkg.add("JLD2")
julia> Pkg.add("ProgressMeter")
julia> Pkg.add("DataStructures")
julia> Pkg.add("Distributions")
julia> Pkg.clone("https://github.com/hshindo/TSGs.jl.git")
```

## Data Format
```
(TOP(S(NP(NNS(Analysts)))(VP(VBP(are))(ADJP(JJ(downbeat))(PP(IN(about))(NP(NP(NP(NNP(IBM))(POS('s)))(NN(outlook)))(PP(IN(for))(NP(DT(the))(JJ(next))(JJ(few))(NNS(quarters))))))))(.(.))))
```

## Usage
Copy `main.jl` to your preferred directory and edit as you like.
Then,
```
julia main.jl
```
