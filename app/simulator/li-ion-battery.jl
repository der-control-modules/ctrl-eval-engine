struct LiIonBatterySpecs
    powerCapacityKw::Float64
    energyCapacityKwh::Float64
    C0::Float64 # self-discharge coefficient
    C_p::Float64 # discharging efficiency
    C_n::Float64 # charging efficiency
    H_p::Float64 # discharging efficiency degradation coef
    H_n::Float64 # charging efficiency degradation coef
    D::NTuple{3,Float64} # degradation coefficients
end

mutable struct LiIonBatteryStates
    SOC::Float64 # state of charge
    d::Float64 # degradation
end

struct LiIonBattery <: EnergyStorageSystem
    specs::LiIonBatterySpecs
    states::LiIonBatteryStates
end


SOC(ess::LiIonBattery) = ess.states.SOC

SOH(ess::LiIonBattery) = ess.specs.C_p / (ess.specs.C_p + ess.specs.H_p * ess.states.d)

p_max(ess::LiIonBattery, durationHour::Real) = min(
    ess.specs.powerCapacityKw,
    -(SOC(ess) + ess.specs.C0) * ess.specs.energyCapacityKwh / durationHour
    /
    (ess.specs.C_p + ess.specs.H_p * ess.states.d)
)

p_min(ess::LiIonBattery, durationHour::Real) = max(
    -ess.specs.powerCapacityKw,
    (1 - SOC(ess) - ess.specs.C0) * ess.specs.energyCapacityKwh / durationHour
    /
    (ess.specs.C_n + ess.specs.H_n * ess.states.d)
)

Δd(s, p, D::NTuple{3,Float64}, durationHour::Real) = exp(D[1] * s + D[2] * p + D[3] * p^2) * durationHour

"""
    _operate!(ess, powerKw, durationHour)

Operate `ess` with `powerKw` for `durationHour` hours
"""
function _operate!(ess::LiIonBattery, powerKw::Real, durationHour::Real)
    pNorm = powerKw / ess.specs.energyCapacityKwh
    ess.states.d += Δd(SOC(ess), pNorm, ess.specs.D, durationHour)
    ess.states.SOC += ess.specs.C0 + (
        pNorm > 0
        ? pNorm * (ess.specs.C_p + ess.specs.H_p * ess.states.d)
        : pNorm * (ess.specs.C_n + ess.specs.H_n * ess.states.d)
    ) * durationHour
end