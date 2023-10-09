"""
    EnergyStorageSimulators

The `EnergyStorageSimulators` provides type and functions for simulating the operation and behaviors of energy storage systems.
"""
module EnergyStorageSimulators

using Dates

export EnergyStorageSystem,
    MockSimulator,
    LiIonBattery,
    operate!,
    get_ess,
    SOC,
    SOH,
    p_max,
    p_min,
    e_max,
    e_min,
    energy_state,
    ηRT
using CtrlEvalEngine

abstract type EnergyStorageSystem end

include("mock-simulator.jl")
include("li-ion-battery.jl")

"""
    get_ess(input::Dict)

Construct the appropriate EnergyStorageSystem object based on `input`
"""
function get_ess(input::Dict)
    try
        powerCapKw = if lowercase(input["powerCapacityUnit"]) == "kw"
            float(input["powerCapacityValue"])
        elseif lowercase(input["powerCapacityUnit"]) == "mw"
            float(input["powerCapacityValue"]) * 1000
        else
            throw(
                InvalidInput(
                    string(
                        "Unsupported unit for ESS power capacity - ",
                        input["powerCapacityUnit"],
                    ),
                ),
            )
        end

        energyCapKwh = if input["calculationType"] == "duration"
            powerCapKw * float(input["duration"])
        else
            float(input["energyCapacity"])
        end

        ηRT = float(input["roundtripEfficiency"])

        cycleLife = float(input["cycleLife"])

        ess = if input["batteryType"] == "lfp-lithium-ion"
            LiIonBattery(
                LFP_LiIonBatterySpecs(powerCapKw, energyCapKwh, ηRT, cycleLife),
                LiIonBatteryStates(0.5, 0),
            )
        elseif input["batteryType"] == "nmc-lithium-ion"
            LiIonBattery(
                NMC_LiIonBatterySpecs(powerCapKw, energyCapKwh, ηRT, cycleLife),
                LiIonBatteryStates(0.5, 0),
            )
        elseif input["batteryType"] ∈ ("mock", "vanadium-flow")
            MockSimulator(MockES_Specs(powerCapKw, energyCapKwh, ηRT), MockES_States(0.5))
        else
            throw(InvalidInput(string("Unsupported ESS type - ", input["batteryType"])))
        end
        return ess
    catch e
        if e isa KeyError
            throw(InvalidInput("Missing key in ESS parameter - \"$(e.key)\""))
        else
            rethrow()
        end
    end
end

"""
    operate!(ess, powerKw, duration, ambientTemperatureDegreeC) -> actualPowerKw

Operate `ess` with `powerKw` for `duration` while ambient temperature is `ambientTemperatureDegreeC`
and returns the actual charging/discharging power considering operational constraints.
"""
function operate!(
    ess::EnergyStorageSystem,
    powerKw::Real,
    duration::Dates.Period = Hour(1),
    ambientTemperatureDegreeC::Real = 20,
)
    durationHour = /(promote(duration, Hour(1))...)

    if powerKw > p_max(ess, durationHour, ambientTemperatureDegreeC)
        @warn "Operation attempt exceeds power upper bound. Falling back to bound." maxlog =
            10 powerKw upper_bound = p_max(ess, durationHour, ambientTemperatureDegreeC) SOC =
            SOC(ess) SOH = SOH(ess) ambientTemperatureDegreeC
        powerKw = p_max(ess, durationHour, ambientTemperatureDegreeC)
    elseif powerKw < p_min(ess, durationHour, ambientTemperatureDegreeC)
        @warn "Operation attempt exceeds power lower bound. Falling back to bound." maxlog =
            10 powerKw lower_bound = p_min(ess, durationHour, ambientTemperatureDegreeC) SOC =
            SOC(ess) SOH = SOH(ess) ambientTemperatureDegreeC
        powerKw = p_min(ess, durationHour, ambientTemperatureDegreeC)
    end

    _operate!(ess, powerKw, durationHour, ambientTemperatureDegreeC)
    return powerKw
end

"""
    SOH(ess::EnergyStorageSystem)

Calculate the state of health (SOH) of an ESS.
"""
SOH(ess::EnergyStorageSystem) = 1

"""
    p_max(ess::EnergyStorageSystem, duration::Dates.Period, ambientTemperatureDegreeC::Real)

Calculate the maximum power output (positive means discharging, negative means charging)
of `ess` lasting for a time period of `duration`.
"""
function p_max(
    ess::EnergyStorageSystem,
    duration::Dates.Period,
    ambientTemperatureDegreeC::Real = 20,
)
    durationHour = /(promote(duration, Hour(1))...)
    p_max(ess, durationHour, ambientTemperatureDegreeC)
end

"""
    p_min(ess::EnergyStorageSystem, duration::Dates.Period, ambientTemperatureDegreeC::Real)

Calculate the minimum power output (negative means charging, positive means discharging)
of `ess` lasting for a time period of `duration`.
"""
function p_min(
    ess::EnergyStorageSystem,
    duration::Dates.Period,
    ambientTemperatureDegreeC::Real = 20,
)
    durationHour = /(promote(duration, Hour(1))...)
    p_min(ess, durationHour, ambientTemperatureDegreeC)
end

end