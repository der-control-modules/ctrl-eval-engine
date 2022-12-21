
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
    operate!(ess, powerKw, duration)

Operate `ess` with `powerKw` for `duration`
"""
function operate!(ess::MockSimulator, powerKw::Real, duration::Dates.Period=Hour(1))
    if abs(powerKw) > ess.specs.powerCapacityKw
        error("Operating power exceeds power capacity")
    end

    durationHour = /(promote(duration, Hour(1))...)

    newSOC = ess.states.SOC - (
        powerKw > 0
        ? powerKw / ess.specs.efficiency
        : powerKw * ess.specs.efficiency
    ) * durationHour / ess.specs.energyCapacityKwh

    if newSOC > 1 || newSOC < 0
        error("Operating with provided power would cause SOC to go out of bounds")
    end

    ess.states.SOC = newSOC
end

SOC(ess::MockSimulator) = ess.states.SOC
