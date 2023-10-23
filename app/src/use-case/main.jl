"""
    EnergyStorageUseCases

The `EnergyStorageUseCases` provides type and functions for use cases
"""
module EnergyStorageUseCases

export UseCase,
    get_use_cases,
    calculate_metrics,
    calculate_net_benefit,
    use_case_charts,
    EnergyArbitrage,
    forecast_price,
    Regulation,
    RegulationPricePoint,
    RegulationOperationPoint,
    regulation_income,
    LoadFollowing,
    VariabilityMitigation,
    PeakLimiting,
    GenerationFollowing

abstract type UseCase end

using Dates
using CtrlEvalEngine
using CtrlEvalEngine: SimSetting, Progress, ScheduleHistory, OperationHistory
using LinearAlgebra
using JuMP

include("energy-arbitrage.jl")
include("regulation.jl")
include("variability-mitigation.jl")
include("load-following.jl")
include("peak-limiting.jl")
include("generation-following.jl")

get_use_cases(inputDict::Dict, setting::SimSetting) = [
    if name === "Energy Arbitrage"
        EnergyArbitrage(config["data"], setting.simStart, setting.simEnd)
    elseif name === "Power Smoothing"
        VariabilityMitigation(config["data"], setting.simStart, setting.simEnd)
    elseif name === "Load Following"
        LoadFollowing(config["data"], setting.simStart, setting.simEnd)
    elseif name === "Generation Following"
        GenerationFollowing(config["data"], setting.simStart, setting.simEnd)
    elseif name === "Frequency Regulation"
        Regulation(config["data"], setting.simStart, setting.simEnd)
    else
        throw(InvalidInput("Unknown use case: $name"))
    end for (name, config) in inputDict
]

# Return zero if a use-case-specific method is not implemented
calculate_net_benefit(::Progress, ::UseCase) = 0.0

# Return an empty vector if a use-case-specific method is not implemented
calculate_metrics(::ScheduleHistory, ::OperationHistory, ::UseCase) = []

# Return an empty vector if a use-case-specific method is not implemented
use_case_charts(::ScheduleHistory, ::OperationHistory, ::UseCase) = []

end