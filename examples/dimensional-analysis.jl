

#=

Cf on increasing d, the behaviour of V(X)

- adaptive hit and run 
- HMC 

=#


using AdvancedHMC, ForwardDiff
using LogDensityProblems
using LinearAlgebra

using Pigeons
using LinearRegression

using MCMCDiagnosticTools
using MCMCChains

using Statistics
using Plots 

# Define the target distribution using the `LogDensityProblem` interface
struct LogTargetDensity
    dim::Int
end
LogDensityProblems.logdensity(p::LogTargetDensity, θ) = -sum(abs2, θ) / 2  # standard multivariate normal
LogDensityProblems.dimension(p::LogTargetDensity) = p.dim
LogDensityProblems.capabilities(::Type{LogTargetDensity}) = LogDensityProblems.LogDensityOrder{0}()



function nuts(D)
    # Choose parameter dimensionality and initial parameter value
    initial_θ = rand(D)
    logp = LogTargetDensity(D)

    # Set the number of samples to draw and warmup iterations
    n_samples, n_adapts = 2_000, 1_000

    # Define a Hamiltonian system
    metric = DiagEuclideanMetric(D)
    hamiltonian = Hamiltonian(metric, logp, ForwardDiff)

    # Define a leapfrog solver, with initial step size chosen heuristically
    initial_ϵ = find_good_stepsize(hamiltonian, initial_θ)
    integrator = Leapfrog(initial_ϵ)

    # Define an HMC sampler, with the following components
    #   - multinomial sampling scheme,
    #   - generalised No-U-Turn criteria, and
    #   - windowed adaption for step-size and diagonal mass matrix
    proposal = NUTS{MultinomialTS, GeneralisedNoUTurn}(integrator)
    adaptor = StanHMCAdaptor(MassMatrixAdaptor(metric), StepSizeAdaptor(0.8, integrator))

    # Run the sampler to draw samples from the specified Gaussian, where
    #   - `samples` will store the samples
    #   - `stats` will store diagnostic statistics for each sample
    samples, stats = sample(hamiltonian, proposal, initial_θ, n_samples, adaptor, n_adapts; progress=false)

    # next: compute logp on each sample
    vs = map(s -> LogDensityProblems.logdensity(logp, s), samples)

    # estimate cost per ESS
    @show n_steps = sum(map(s -> s.n_steps, stats))
    @show ess_value = compute_ess(vs)
    return D*n_steps/ess_value
end

function hit_run(D)
    nr = 10 + ceil(Int, log(D))
    p = pigeons(
            target = toy_mvn_target(D),
            n_chains = 1, 
            n_rounds = nr,
            show_report = false,
            explorer = Pigeons.AHR(), 
            recorder_builders = [traces])
    samples = get_sample(p, 1) 

    logp = LogTargetDensity(D)
    vs = map(s -> LogDensityProblems.logdensity(logp, s), samples)

    @show n_steps = 2^nr 
    @show ess_value = compute_ess(vs) 
    return D*n_steps/ess_value
end

sparse_slicer(D) = slicer(D, true) 
dense_slicer(D) = slicer(D, false)

function slicer(D, sparse::Bool)
    nr = 10
    p = pigeons(
            target = toy_mvn_target(D),
            n_chains = 1, 
            n_rounds = nr,
            show_report = false,
            explorer = Pigeons.SliceSampler(), 
            recorder_builders = [traces])
    samples = get_sample(p, 1) 

    logp = LogTargetDensity(D)
    vs = map(s -> LogDensityProblems.logdensity(logp, s), samples)

    @show n_steps = 2^nr 
    @show ess_value = compute_ess(vs) 
    return (sparse ? D : D^2)*n_steps/ess_value
end

function compute_ess(vs) 
    ess_df = ess(Chains(vs, [:V]))
    return ess_df.nt.ess[1]
end

function scaling_plot(max, n_replicates = 1)
    sampling_fcts = [sparse_slicer, dense_slicer, nuts, hit_run]
    p = plot()
    data = Dict()
    for sampling_fct in sampling_fcts
        sampler_symbol = Symbol(sampling_fct)
        sampler_name = String(sampler_symbol)
        println("Sampler: $(sampler_name)")
        dims = Float64[]
        costs = Float64[]
        for i in 0:max
            @show D = 2^i
            replicates = [sampling_fct(D) for j in 1:n_replicates]
            push!(dims, D)
            push!(costs, mean(replicates))
        end
        sampler_name = String(Symbol(sampling_fct))
        p = plot!(dims, costs, 
                xaxis=:log, yaxis=:log, 
                legend = :outertopleft,
                xlabel = "dimensionality", 
                ylabel = "evals per ESS", 
                label = sampler_name)
        data[sampler_symbol] = (; dims, costs)
    end

    filename_prefix = "benchmarks/scalings_nrep=$(n_replicates)_max=$max"

    open("$filename_prefix.txt", "w") do io
        for (k, v) in data 
            xs = log.(v.dims)
            ys = log.(v.costs)
            slope = LinearRegression.slope(linregress(xs, ys))[1]
            println(io, "$k: $slope")
        end
    end

    savefig(p, "$filename_prefix.pdf")

    return p
end