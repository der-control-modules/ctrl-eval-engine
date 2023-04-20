"""
    EnergyStorageUseCases

The `EnergyStorageUseCases` provides type and functions for 
"""
module EnergyStorageUseCases

export UseCase, get_use_cases, summarize_use_case, calculate_net_income, EnergyArbitrage, Regulation

abstract type UseCase end

using Dates
using CtrlEvalEngine: OperationHistory, start_time, end_time

"""
    TimeSeriesPrice

`TimeSeriesPrice` represents the price `value` over a period of time with corresponding timestamps `t`.
`length(t)` should equal to `length(price) + 1`.
"""
struct TimeSeriesPrice
    t::Vector{Dates.DateTime}
    value::Vector{Float64} # unit: $/kWh
end


include("energy-arbitrage.jl")
include("regulation.jl")

function get_use_cases(inputDict::Dict)
    return [EnergyArbitrage(inputDict["Energy Arbitrage"]["data"])]
end

end