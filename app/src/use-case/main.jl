"""
    EnergyStorageUseCases

The `EnergyStorageUseCases` provides type and functions for 
"""
module EnergyStorageUseCases

export UseCase, get_use_cases, calculate_metrics, calculate_net_income, EnergyArbitrage, Regulation, RegulationOperationPoint, regulation_income

abstract type UseCase end

using Dates
using CtrlEvalEngine: OperationHistory, power, TimeSeries, FixedIntervalTimeSeries, VariableIntervalTimeSeries, start_time, end_time
using LinearAlgebra
using JuMP

include("energy-arbitrage.jl")
include("regulation.jl")

function get_use_cases(inputDict::Dict)
    return [EnergyArbitrage(inputDict["Energy Arbitrage"]["data"])]
end

end