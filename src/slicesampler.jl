"""
    SliceSampler

Neal, R. M. (2003). Slice sampling. Annals of statistics, 705-741.
Implementation of "doubling procedure".
"""
mutable struct SliceSampler
    logf::Function
    x::Float64
    logy::Float64
    minx::Float64
    maxx::Float64
    width::Float64
    xl::Float64
    xr::Float64
end

function SliceSampler(logf::Function, x::Float64, minx::Float64, maxx::Float64)
    SliceSampler(logf, x, 0.0, minx, maxx, 0.01, 0.0, 0.0)
end

function next!(sampler::SliceSampler)
    sampler.logy = sampler.logf(sampler.x) + log(rand()+1e-100)
    findrange!(sampler)
    x = shrink!(sampler)
    if sampler.minx <= x <= sampler.maxx
        sampler.width = abs(sampler.x - x)
        sampler.x = x
        x
    else
        throw("x: $x is invalid.")
    end
end

"""
p.11 Figure 4
"""
function findrange!(sampler::SliceSampler)
    l = max(sampler.x - sampler.width*rand(), sampler.minx)
    r = min(l + sampler.width, sampler.maxx)
    w = sampler.width
    while sampler.logy < sampler.logf(l)
        l -= w
        if l < sampler.minx
            l = sampler.minx
            break
        end
        w *= 2.0
    end
    w = sampler.width
    while sampler.logy < sampler.logf(r)
        r += w
        if r > sampler.maxx
            r = sampler.maxx
            break
        end
        w *= 2.0
    end
    sampler.xl = l
    sampler.xr = r
end

"""
p.13 Figure 5
"""
function shrink!(sampler::SliceSampler)
    x = 0.0
    b = true
    while b
        x = sampler.xl + rand() * (sampler.xr - sampler.xl)
        sampler.logy < sampler.logf(x) && check(sampler,x) && (b = false)
        if x < sampler.x
            sampler.xl = x
        else
            sampler.xr = x
        end
    end
    x
end

"""
p.13 Figure 6
"""
function check(sampler::SliceSampler, x::Float64)
    l, r = sampler.xl, sampler.xr
    while (r-l) > 1.1*sampler.width
        m = (l+r) / 2.0
        d = (sampler.x < m && x >= m) || (sampler.x >= m && x < m)
        if x < m
            r = m
        else
            l = m
        end
        logy = sampler.logy
        logf = sampler.logf
        if d && logy >= logf(l) && logy >= logf(r)
            return false
        end
    end
    true
end

function test_slicesampler()
    m1, m2, v, pi = 0.0, 10.0, 3.0, 0.2
    function f(x)
        y1 = exp(-(x-m1) * (x-m1) / 2v) + 1e-100
        y2 = exp(-(x-m2) * (x-m2) / 2v) + 1e-100
        log(pi * y1 + (1.0-pi) * y2)
    end
    sampler = SliceSampler(f, 0.0, realmin(Float64), realmax(Float64))
    for i = 1:1000
        x = next!(sampler)
        println(x)
    end
end
