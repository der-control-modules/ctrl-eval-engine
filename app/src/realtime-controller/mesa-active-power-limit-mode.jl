using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod

using MesaEss: MesaController, VertexCurve, RampParams


struct ActivePowerLimitModeController <: MesaController
    maximumChargePercentage::Float64
    maximumDischargePercentage::Float64
end


function modecontrol(
    ess::EnergyStorageSystem,
    controller::ActivePowerLimitModeController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries,
    wip::WorkInProgress
)
maxAllowedChargePower = controller.maximumChargePercentage / 100 * p_max(ess)
maxAllowedDishargePower = controller.maximumDishargePercentage / 100 * p_max(ess)
wip = [
    max(min(schedulePeriod.powerKw[i], maxAllowedDishargePower), maxAllowedChargePower)
    for i in t:mockController.resolution:tEnd
]
end