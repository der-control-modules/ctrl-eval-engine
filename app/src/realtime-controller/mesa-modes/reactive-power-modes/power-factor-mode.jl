using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: MesaController

"""
    PowerFactorMode

Power Factor mode maintains a specified power factor at the point of common coupling.
The mode adjusts reactive power output to achieve the target power factor based on
the active power output.
"""
struct PowerFactorMode <: MesaMode
    params::MesaModeParams
    targetPowerFactor::Float64  # Target power factor (0.0 to 1.0)
    isLeading::Bool  # true for leading, false for lagging
    minimumActivePower::Float64  # Minimum active power threshold for PF control (kW)
    maximumReactivePower::Float64  # Maximum reactive power capability (VARs)
    minimumReactivePower::Float64  # Minimum reactive power capability (VARs)
end

function modecontrol(
    mode::PowerFactorMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries,
    currentIterationPower::Float64
)
    # Check if active power is above minimum threshold
    if abs(currentIterationPower) < mode.minimumActivePower
        return 0.0
    end
    
    # Calculate required reactive power to achieve target power factor
    # Q = P * tan(acos(PF))
    # For leading PF, reactive power is negative (capacitive)
    # For lagging PF, reactive power is positive (inductive)
    
    if mode.targetPowerFactor >= 1.0
        # Unity power factor - no reactive power needed
        return 0.0
    end
    
    # Calculate reactive power magnitude
    angle = acos(mode.targetPowerFactor)
    reactivePowerMagnitude = abs(currentIterationPower) * tan(angle)
    
    # Apply sign based on leading/lagging and power direction
    targetReactivePower = mode.isLeading ? -reactivePowerMagnitude : reactivePowerMagnitude
    
    # Apply current direction sign (discharge positive, charge negative)
    if currentIterationPower < 0
        targetReactivePower = -targetReactivePower
    end
    
    # Apply reactive power limits
    constrainedReactivePower = max(min(targetReactivePower, mode.maximumReactivePower), mode.minimumReactivePower)
    
    return constrainedReactivePower
end
