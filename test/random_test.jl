# Toy example ----------
# using Pigeons

# inputs = Inputs(target = toy_mvn_target(100))
# pt = pigeons(inputs)



# Turing ----------
using Turing

# *Unidentifiable* unconditioned coinflip model with `N` observations.
@model function coinflip_unidentifiable(; N::Int)
    p1 ~ Uniform(0, 1) # prior on p1
    p2 ~ Uniform(0, 1) # prior on p2
    y ~ filldist(Bernoulli(p1*p2), N) # data-generating model
    return y
end;
coinflip_unidentifiable(y::AbstractVector{<:Real}) = coinflip_unidentifiable(; N=length(y)) | (; y)

function flip_model_unidentifiable()
    p_true = 0.5; # true probability of heads is 0.5
    N = 100;
    data = rand(Bernoulli(p_true), N); # generate N data points
    return coinflip_unidentifiable(data)
end

using Pigeons
model = Pigeons.flip_model_unidentifiable()
pt = pigeons(target = TuringLogPotential(model))