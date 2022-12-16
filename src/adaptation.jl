"""
$TYPEDSIGNATURES

Update the annealing schedule. Given the cumulative communication barrier function
in `cumulativebarrier`, find the optimal schedule of size `N`+1.
"""
function updateschedule(cumulativebarrier, N::Int)
    if N == 1
        newschedule = [0.0, 1.0]
    else 
        Λ = cumulativebarrier(1)
        newschedule = zeros(N+1)
        newschedule[N+1] = 1.0
        for i ∈ 1:N-1
            f(x) = cumulativebarrier(x) - Λ*i/N
            newschedule[i+1] = Roots.find_zero(f, (0.0, 1.0), Roots.Bisection())
        end
    end
    return newschedule
end


"""
$TYPEDSIGNATURES

Compute the local communication barrier and cumulative barrier functions from the 
`rejection` rates and the current annealing `schedule`. The estimation of the barriers 
is based on Fritsch-Carlson monotonic interpolation.

Returns a `NamedTuple` with fields:

- `localbarrier`
- `cumulativebarrier`
- `globalbarrier`
"""
function communicationbarrier(rejection::AbstractVector, schedule::AbstractVector)
    @assert length(schedule) == length(rejection) + 1
    x = schedule
    y = [0; cumsum(rejection)]
    spl = Interpolations.interpolate(x, y, FritschCarlsonMonotonicInterpolation())
    cumulativebarrier(β) = spl(β)
    localbarrier(β) = Interpolations.gradient(spl, β)[1]
    globalbarrier = sum(rejection)
    return (; localbarrier, cumulativebarrier, globalbarrier)
end

function communicationbarrier(recorders, schedule::Schedule)
    accept_recorder = recorders.swap_acceptance_pr
    rejection = [1.0 - value(accept_recorder[(i, i+1)]) for i in 1:length(accept_recorder.value.keys)]
    return communicationbarrier(rejection, schedule.grids)
end