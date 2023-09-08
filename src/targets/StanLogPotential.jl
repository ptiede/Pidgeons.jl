"""
Uses `BridgeStan` to perform efficient `ccall` loglikelihood and
allcoation-free gradient calls to a Stan model.

To work with Pigeons `BridgeStan` needs to be imported into
the current session.
"""
@auto struct StanLogPotential
    model
    # keep those to be able to serialize/deserialize
    stan_file
    data
    extra_information # if extra information needed for i.i.d. sampling
end

stan_model(log_potential::StanLogPotential) = log_potential.model
stan_model(log_potential::InterpolatedLogPotential) = log_potential.path.target.model


# These are functions for the stan examples
# TODO: Should these really be in the main repo or the examples folder?
function toy_stan_target end
function toy_stan_unid_target end
function stan_funnel end
function stan_bernoulli end
function stan_eight_schools end



"""
$SIGNATURES

Create a JSON string based on the scalar or array variables
provided.
"""
json(; variables...) =
    "{" *
    join(
        map(
            pair -> "\"$(pair[1])\" : $(pair[2])",
            collect(variables)), ",") *
    "}"
