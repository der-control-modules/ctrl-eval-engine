using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod

# using .MesaEss


struct ActivePowerLimitMode <: MesaMode
    params::MesaModeParams
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
return max(min(controller.wip.value[end], maxAllowedDishargePower), maxAllowedChargePower)
end
