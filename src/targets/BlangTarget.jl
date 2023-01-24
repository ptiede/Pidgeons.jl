""" 
A [`StreamTarget`](@ref) delegating exploration to 
[Blang worker processes](https://www.stat.ubc.ca/~bouchard/blang/).

```@example Blang_Pigeons
using Pigeons

Pigeons.setup_blang("blangDemos") # pre-compile the blang models
pigeons(target = Pigeons.blang_ising());
```

Limitation: this should be called on a pre-compiled blang model, 
i.e. via `java package.MyBlangModel ...`, rather than via 
`blang ...` since the latter could cause several MPI processes to 
simultaneously attempt to compile in the same directory. 
"""
struct BlangTarget <: StreamTarget
    command::Cmd
end

#=  
The only thing that absolutely needs to be implemented on Pigeons' side of the Pigeons-Blang bridge 
is the function below, which passes the rng to the right command line argument,  
calls Blang's Pigeons bridge, and instruct Blang to skips saving standard streams as they will contain 
all the messages between Pigeons and Blang. 
The rest of this file is just convenience function to setup example Blang examples.

The code on Blang's side of the bridge is available at 
this address: 
https://github.com/UBC-Stat-ML/blangSDK/blob/master/src/main/java/blang/engines/internals/factories/Pigeons.java
=#
initialization(target::BlangTarget, rng::SplittableRandom, replica_index::Int64) = 
    StreamState(
        `$(target.command) 
            --experimentConfigs.resultsHTMLPage false
            --experimentConfigs.saveStandardStreams false
            --engine blang.engines.internals.factories.Pigeons 
            --engine.random $(java_seed(rng))`,
        replica_index)

"""
$SIGNATURES 

Model for phylogenetic inference from single-cell copy-number alteration from 
[https://www.biorxiv.org/content/10.1101/2020.05.06.058180](Salehi et al., 2020). 

Use `run(Pigeons.blang_sitka(\`--help\`).command)` for more information.
"""
blang_sitka(model_options) = 
    BlangTarget(`$(blang_executable("nowellpack", "corrupt.NoisyBinaryModel")) $model_options`)

"""
$SIGNATURES 

Default options for the 535 dataset in 
[https://www.biorxiv.org/content/10.1101/2020.05.06.058180](Salehi et al., 2020).   
"""
blang_sitka() = blang_sitka(`
        --model.binaryMatrix $(blang_repo_path("nowellpack"))/examples/535/filtered.csv 
        --model.globalParameterization true 
        --model.fprBound 0.005 
        --model.fnrBound 0.5 
        --model.minBound 0.001  
        --model.samplerOptions.useCellReallocationMove true  
        --model.predictivesProportion 0.0  
        --model.samplerOptions.useMiniMoves true
    `)

""" 
$SIGNATURES 

Two-dimensional Ising model.

Use `run(Pigeons.blang_ising(\`--help\`).command)` for more information.
"""
blang_ising(model_options) = 
    BlangTarget(
        `$(blang_executable("blangDemos", "blang.validation.internals.fixtures.Ising")) $model_options`
    )

"""
$SIGNATURES 

15x15 Ising model. 
"""
blang_ising() = blang_ising(`--model.N 15`)

"""
$SIGNATURES 

Download the github repo with the given `repo_name` and `organization` in ~.pigeons, 
and compile the blang code. 
"""
function setup_blang(
        repo_name, 
        organization = "UBC-Stat-ML")

    auto_install_folder = mkpath(mpi_settings_folder())
    repo_path = "$auto_install_folder/$repo_name"
    if isdir(repo_path)
        @info "it seems setup_blang() was alrady ran for $repo_name; to force re-runing the setup for $repo_name, first remove the folder $repo_path"
        return nothing
    end

    cd(auto_install_folder) do
        run(`git clone git@github.com:$organization/$repo_name.git`)
    end 

    cd(repo_path) do
        run(`$repo_path/gradlew installDist`)
    end 
    return nothing
end

# Internals

blang_repo_path(repo_name) = 
    "$(mkpath(mpi_settings_folder()))/$repo_name"

function blang_executable(repo_name, qualified_main_class)
    repo_path = blang_repo_path(repo_name)
    if !isdir(repo_path)
        error("run Pigeons.setup_blang(\"$repo_name\") first (this only needs to be done once)")
    end
    libs = "$repo_path/build/install/$repo_name/lib/"
    return `java -cp $libs/\* $qualified_main_class`
end