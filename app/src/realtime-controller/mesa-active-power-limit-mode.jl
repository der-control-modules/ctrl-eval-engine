using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod

using MesaEss: MesaController, VertexCurve, RampParams


struct ActivePowerLimitMode <: MesaMode
    maximumChargePercentage::Float64
    maximumDischargePercentage::Float64
end


function modecontrol(
    mode::ActivePowerLimitMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    _,
    _,
    t::Dates.DateTime,
    _
)
maxAllowedChargePower = mode.maximumChargePercentage / 100 * p_min(ess)
maxAllowedDishargePower = mode.maximumDishargePercentage / 100 * p_max(ess)
tEnd = t + ceil(EnergyStorageScheduling.end_time(schedulePeriod) - t, controller.resolution) - controller.resolution
controller.wip.value = [
    max(min(controller.wip.value[i], maxAllowedDishargePower), maxAllowedChargePower)
    for i in t:controller.resolution:tEnd
]
end
