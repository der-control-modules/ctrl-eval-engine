"""
    EnergyStorageSimulators

The `EnergyStorageSimulators` provides type and functions for simulating the operation and behaviors of energy storage systems.
"""
module EnergyStorageSimulators

using Dates

export EnergyStorageSystem, MockSimulator, operate!, get_ess, SOC
using ..Main: InvalidInput

abstract type EnergyStorageSystem end

include("mock-simulator.jl")
include("li-ion-battery.jl")

function get_ess(input::Dict)
    powerCapKw = if lowercase(input["powerCapacityUnit"]) == "kw"
        parse(Float64, input["powerCapacityValue"])
    elseif lowercase(input["powerCapacityUnit"]) == "mw"
        parse(Float64, input["powerCapacityValue"]) * 1000
    else
        throw(InvalidInput(string("ESS parameter - Unsupported powerCapacityUnit: ", input["powerCapacityUnit"])))
    end

    energyCapKwh = if input["calculationType"] == "duration"
        powerCapKw * parse(Float64, input["duration"])
    else
        parse(Float64, input["energyCapacity"])
    end

    return MockSimulator(
        MockES_Specs(powerCapKw, energyCapKwh, 0.9),
        MockES_States(0.5)
    )
end

"""
    operate!(ess, powerKw, duration) -> actualPowerKw

Operate `ess` with `powerKw` for `duration` 
and returns the actual charging/discharging power considering operational constraints.
"""
function operate!(ess::EnergyStorageSystem, powerKw::Real, duration::Dates.Period=Hour(1))
    durationHour = /(promote(duration, Hour(1))...)

    if powerKw > p_max(ess, durationHour)
        @warn "Operation attempt exceeds power upper bound. Falling back to bound." powerKw upper_bound=p_max(ess, durationHour)
        powerKw = p_max(ess, durationHour)
    elseif powerKw < p_min(ess, durationHour)
        @warn "Operation attempt exceeds power lower bound. Falling back to bound." powerKw lower_bound=p_min(ess, durationHour)
        powerKw = p_min(ess, durationHour)
    end

    _operate!(ess, powerKw, durationHour)
    return powerKw
end

"""
    SOH(ess::EnergyStorageSystem)

Calculate the state of health of an ESS.
"""
SOH(ess::EnergyStorageSystem) = 1

end