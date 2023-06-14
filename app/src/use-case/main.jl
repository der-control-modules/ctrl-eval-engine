"""
    EnergyStorageUseCases

The `EnergyStorageUseCases` provides type and functions for 
"""
module EnergyStorageUseCases

export UseCase, get_use_cases, calculate_metrics, calculate_net_benefit, use_case_charts,
    EnergyArbitrage,
    Regulation, RegulationOperationPoint, regulation_income,
    LoadFollowing,
    VariabilityMitigation

abstract type UseCase end

using Dates
using CtrlEvalEngine: Progress, OperationHistory, power, TimeSeries, FixedIntervalTimeSeries, VariableIntervalTimeSeries, start_time, end_time
using LinearAlgebra
using JuMP

include("energy-arbitrage.jl")
include("regulation.jl")
include("variability-mitigation.jl")
include("load-following.jl")

function get_use_cases(inputDict::Dict)
    return map(inputDict) do (name, config)
        if name === "Energy Arbitrage"
            EnergyArbitrage(config["data"])
        elseif name === "Variability Mitigation"
            VariabilityMitigation(config)
        else
            throw(InvalidInput("Unknown use case: $name"))
        end
    end
end

# Return zero if a use-case-specific method is not implemented
calculate_net_benefit(::Progress, ::UseCase) = 0.0

# Return an empty vector if a use-case-specific method is not implemented
calculate_metrics(::OperationHistory, ::UseCase) = []

# Return an empty vector if a use-case-specific method is not implemented
use_case_charts(::OperationHistory, ::UseCase) = []

end