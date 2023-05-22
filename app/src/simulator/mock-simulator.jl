
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
    _operate!(ess, powerKw, durationHour)

Operate `ess` with `powerKw` for `durationHour` hours
"""
function _operate!(ess::MockSimulator, powerKw::Real, durationHour::Real)
    ess.states.SOC = ess.states.SOC - (
        powerKw > 0
        ? powerKw / ess.specs.efficiency
        : powerKw * ess.specs.efficiency
    ) * durationHour / ess.specs.energyCapacityKwh
end

SOC(ess::MockSimulator) = ess.states.SOC

p_max(ess::MockSimulator, durationHour::Real) = min(
    ess.specs.powerCapacityKw,
    SOC(ess) * ess.specs.energyCapacityKwh / durationHour * ess.specs.efficiency
)

p_min(ess::MockSimulator, durationHour::Real) = max(
    -ess.specs.powerCapacityKw,
    (SOC(ess) - 1) * ess.specs.energyCapacityKwh / durationHour / ess.specs.efficiency
)

ηRT(ess::MockSimulator) = 1
