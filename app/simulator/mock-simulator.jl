
struct MockES_Specs
    powerCapacityKw::Float64
    energyCapacityKwh::Float64
    efficiency::Float64
end

mutable struct MockES_States
    SOC::Float64 # state of charge
end

struct MockSimulator <: EnergyStorageSystem
    specs::MockES_Specs
    states::MockES_States
end

"""
    operate!(ess, powerKw, duration) -> actualPowerKw

Operate `ess` with `powerKw` for `duration`
"""
function operate!(ess::MockSimulator, powerKw::Real, duration::Dates.Period=Hour(1))
    if abs(powerKw) > ess.specs.powerCapacityKw
        @warn "Operation attempt exceeds power capacity. Falling back to capacity." powerKw
        powerKw = copysign(ess.specs.powerCapacityKw, powerKw)
    end

    durationHour = /(promote(duration, Hour(1))...)

    newSOC = ess.states.SOC - (
        powerKw > 0
        ? powerKw / ess.specs.efficiency
        : powerKw * ess.specs.efficiency
    ) * durationHour / ess.specs.energyCapacityKwh

    if newSOC > 1
        @warn "Operating with provided power would cause SOC to go above the upper bound. Falling back to bound."
        powerKw *= (1 - SOC(ess)) / (newSOC - SOC(ess))
        newSOC = 1
    elseif newSOC < 0
        @warn "Operating with provided power would cause SOC to go below the lower bound. Falling back to bound."
        powerKw *= (0 - SOC(ess)) / (newSOC - SOC(ess))
        newSOC = 0
    end

    ess.states.SOC = newSOC
    return powerKw
end

SOC(ess::MockSimulator) = ess.states.SOC
