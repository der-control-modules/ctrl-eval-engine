struct VRFBatterySpecs
    powerCapacityKw::Float64
    energyCapacityKwh::Float64
    TsetDegreeC::Float64
    C0::Float64 # self-discharge coefficient
    C0Hot::Float64 # self-discharge coefficient adjustment when ambient temperature is higher than Tset
    C0Cold::Float64 # self-discharge coefficient adjustment when ambient temperature is lower than Tset
    C1::Float64 # Unit: 1/kWh P
    C2::Float64 # P^2 Unit: 1/kW^2/h
    C3::Float64 # 1/SOC^2 Unit: 1/h 
    C4::Float64 # P/SOC Unit: 1/kWh
    C5::Float64 # P/SOC^2 Unit: 1/kWh
end

function VRFBatterySpecs(P, E)
    TsetDegreeC = 9.54887218045112
    C0 = -2.52E-02
    C0Hot = 0.022958651
    C0Cold = -0.080177305
    C1 = -1.40E-01
    C2 = -1.02E+00
    C3 = -1.05E-03
    C4 = -4.84E-01
    C5 = 2.16E-02
    VRFBatterySpecs(P, E, TsetDegreeC, C0, C0Hot, C0Cold, C1, C2, C3, C4, C5)
end

mutable struct VRFBatteryStates
    SOC::Float64 # state of charge
end

struct VRFBattery <: EnergyStorageSystem
    specs::VRFBatterySpecs
    states::VRFBatteryStates
end

ηRT(specs::VRFBatterySpecs) = begin
    ess = VRFBattery(specs, VRFBatteryStates(0.5))
    ηRT(ess)
end

ηRT(ess::VRFBattery) =
    ΔSOC(
        ess,
        -ess.specs.powerCapacityKw / ess.specs.energyCapacityKwh,
        1,
        ess.specs.TsetDegreeC,
    ) /
    -ΔSOC(
        ess,
        ess.specs.powerCapacityKw / ess.specs.energyCapacityKwh,
        1,
        ess.specs.TsetDegreeC,
    )

SOC(ess::VRFBattery) = ess.states.SOC
energy_state(ess::VRFBattery) = ess.states.SOC * ess.specs.energyCapacityKwh

e_max(ess::VRFBattery) = ess.specs.energyCapacityKwh
e_min(_::VRFBattery) = 0

p_max(specs::VRFBatterySpecs) = specs.powerCapacityKw
p_max(ess::VRFBattery) = p_max(ess.specs)

function p_max(ess::VRFBattery, durationHour::Real, ambientTemperatureDegreeC::Real)
    p_max(ess)
end

p_min(specs::VRFBatterySpecs) = -specs.powerCapacityKw
p_min(ess::VRFBattery) = p_min(ess.specs)

function p_min(ess::VRFBattery, durationHour::Real, ambientTemperatureDegreeC::Real)
    p_min(ess)
end

"""
    ΔSOC(ess::VRFBattery, p_p, p_n, durationHour::Real, temperatureDegreeC::Real)

Calculate the change of SOC of `ess` given `p_p` and `p_n`, where
`p_p` is non-negative (discharging) power, `p_n` is the non-positive (charging) power,
and they shouldn't be non-zero simultaneously.

Note: both `p_p` and `p_n` should be normalized by the energy capacity.
"""
function ΔSOC(ess::VRFBattery, p, durationHour::Real, ambientTemperatureDegreeC::Real)
    ΔT = ambientTemperatureDegreeC - ess.specs.TsetDegreeC
    durationHour * (
        ess.specs.C0 * (1 + ΔT * (ΔT > 0 ? ess.specs.C0Hot : ess.specs.C0Cold)) +
        ess.specs.C1 * p +
        ess.specs.C2 * p^2 +
        ess.specs.C3 / SOC(ess)^2 +
        ess.specs.C4 * p / SOC(ess) +
        ess.specs.C5 * p / SOC(ess)^2
    )
end

"""
    _operate!(ess, powerKw, durationHour)

Operate `ess` with `powerKw` for `durationHour` hours
"""
function _operate!(
    ess::VRFBattery,
    powerKw::Real,
    durationHour::Real,
    temperatureDegreeC::Real,
)
    pNorm = powerKw / ess.specs.energyCapacityKwh
    ess.states.SOC += ΔSOC(ess, pNorm, durationHour, temperatureDegreeC)
    ess.states.SOC = min(max(ess.states.SOC, 0), 1)
end