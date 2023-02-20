"""
    EnergyStorageUseCases

The `EnergyStorageUseCases` provides type and functions for 
"""
module EnergyStorageUseCases

export UseCase, get_use_cases, summarize_use_case

abstract type UseCase end

using Dates
using ..Main: OperationHistory

include("energy-arbitrage.jl")

function get_use_cases(inputDict::Dict)
    return [EnergyArbitrage(inputDict["Energy Arbitrage"]["data"])]
end

end