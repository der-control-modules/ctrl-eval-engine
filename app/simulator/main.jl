"""
    EnergyStorageSimulators

The `EnergyStorageSimulators` provides type and functions for simulating the operation and behaviors of energy storage systems.
"""
module EnergyStorageSimulators

using Dates

export EnergyStorageSystem, MockSimulator, operate!, get_ess, SOC, p_max, p_min
using ..Main: InvalidInput

abstract type EnergyStorageSystem end

include("mock-simulator.jl")
include("li-ion-battery.jl")

"""
    get_ess(input::Dict)

Construct the appropriate EnergyStorageSystem object based on `input`
"""
function get_ess(input::Dict)
    powerCapKw = if lowercase(input["powerCapacityUnit"]) == "kw"
        float(input["powerCapacityValue"])
    elseif lowercase(input["powerCapacityUnit"]) == "mw"
        float(input["powerCapacityValue"]) * 1000
    else
        throw(InvalidInput(string("ESS parameter - Unsupported powerCapacityUnit: ", input["powerCapacityUnit"])))
    end

    energyCapKwh = if input["calculationType"] == "duration"
        powerCapKw * float(input["duration"])
    else
        float(input["energyCapacity"])
    end

    ηRT = float(input["roundtripEfficiency"])

    cycleLife = float(input["cycleLife"])

    ess = if input["batteryType"] == "lfp-lithium-ion"
        LiIonBattery(LFP_LiIonBatterySpecs(powerCapKw, energyCapKwh, ηRT, cycleLife), LiIonBatteryStates(0.5, 0))
    elseif input["batteryType"] == "nmc-lithium-ion"
        LiIonBattery(NMC_LiIonBatterySpecs(powerCapKw, energyCapKwh, ηRT, cycleLife), LiIonBatteryStates(0.5, 0))
    elseif input["batteryType"] ∈ ("mock", "vanadium-flow")
        MockSimulator(
            MockES_Specs(powerCapKw, energyCapKwh, ηRT),
            MockES_States(0.5)
        )
    else
        throw(InvalidInput(string("ESS Parameter - Unsupported batteryType: ", input["batteryType"])))
    end

    return ess
end

"""
    operate!(ess, powerKw, duration) -> actualPowerKw

Operate `ess` with `powerKw` for `duration` 
and returns the actual charging/discharging power considering operational constraints.
"""
function operate!(ess::EnergyStorageSystem, powerKw::Real, duration::Dates.Period=Hour(1))
    durationHour = /(promote(duration, Hour(1))...)

    if powerKw > p_max(ess, durationHour)
        @warn "Operation attempt exceeds power upper bound. Falling back to bound." powerKw upper_bound = p_max(ess, durationHour) SOC = SOC(ess) SOH = SOH(ess)
        powerKw = p_max(ess, durationHour)
    elseif powerKw < p_min(ess, durationHour)
        @warn "Operation attempt exceeds power lower bound. Falling back to bound." powerKw lower_bound = p_min(ess, durationHour) SOC = SOC(ess) SOH = SOH(ess)
        powerKw = p_min(ess, durationHour)
    end

    _operate!(ess, powerKw, durationHour)
    return powerKw
end

"""
    SOH(ess::EnergyStorageSystem)

Calculate the state of health (SOH) of an ESS.
"""
SOH(ess::EnergyStorageSystem) = 1

"""
    p_max(ess::EnergyStorageSystem, duration::Dates.Period=Hour(1))

Calculate the maximum power output (positive means discharging, negative means charging)
of `ess` lasting for a time period of `duration`.
"""
function p_max(ess::EnergyStorageSystem, duration::Dates.Period=Hour(1))
    durationHour = /(promote(duration, Hour(1))...)
    p_max(ess, durationHour)
end

"""
    p_min(ess::EnergyStorageSystem, duration::Dates.Period=Hour(1))

Calculate the minimum power output (negative means charging, positive means discharging)
of `ess` lasting for a time period of `duration`.
"""
function p_min(ess::EnergyStorageSystem, duration::Dates.Period=Hour(1))
    durationHour = /(promote(duration, Hour(1))...)
    p_min(ess, durationHour)
end

end