using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: MesaController

"""
    ReactivePowerLimitMode

Reactive Power Limit mode constrains the reactive power output to specified limits.
This mode acts as a constraint on other reactive power modes by ensuring the 
reactive power output stays within defined boundaries.
"""
struct ReactivePowerLimitMode <: MesaMode
    params::MesaModeParams
    maximumReactivePowerPercent::Float64  # Maximum reactive power as percentage of rating
    minimumReactivePowerPercent::Float64  # Minimum reactive power as percentage of rating
    ratedReactivePower::Float64  # Rated reactive power capability (VARs)
end

function modecontrol(
    mode::ReactivePowerLimitMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries,
    currentIterationReactivePower::Float64
)
    # Calculate maximum and minimum allowed reactive power
    maxAllowedReactivePower = mode.maximumReactivePowerPercent / 100.0 * mode.ratedReactivePower
    minAllowedReactivePower = mode.minimumReactivePowerPercent / 100.0 * mode.ratedReactivePower
    
    # Constrain the reactive power within limits
    constrainedReactivePower = max(min(currentIterationReactivePower, maxAllowedReactivePower), minAllowedReactivePower)
    
    # Return the adjustment needed (delta from current iteration)
    return constrainedReactivePower - currentIterationReactivePower
end
