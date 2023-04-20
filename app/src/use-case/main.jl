"""
    EnergyStorageUseCases

The `EnergyStorageUseCases` provides type and functions for 
"""
module EnergyStorageUseCases

export UseCase, get_use_cases, summarize_use_case, calculate_net_income, EnergyArbitrage, Regulation

abstract type UseCase end

using Dates
using CtrlEvalEngine: OperationHistory, power, TimeSeries, start_time, end_time

include("energy-arbitrage.jl")
include("regulation.jl")

function get_use_cases(inputDict::Dict)
    return [EnergyArbitrage(inputDict["Energy Arbitrage"]["data"])]
end

end