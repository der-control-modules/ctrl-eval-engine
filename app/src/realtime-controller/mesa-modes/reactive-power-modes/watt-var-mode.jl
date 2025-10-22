using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: MesaController, VertexCurve

"""
    WattVARMode

Watt-VAR mode controls reactive power output based on the active power output.
The relationship between active power and reactive power is defined by a user-specified curve.
This mode is useful for coordinating reactive power support with active power dispatch.
"""
struct WattVARMode <: MesaMode
    params::MesaModeParams
    wattVarCurve::VertexCurve  # Curve mapping active power (%) to reactive power (VARs)
    activePowerReference::Float64  # Reference active power for normalization (kW)
    minimumActivePower::Float64  # Minimum active power threshold (kW)
    maximumReactivePower::Float64  # Maximum reactive power capability (VARs)
    minimumReactivePower::Float64  # Minimum reactive power capability (VARs)
    hysteresisPercent::Float64  # Hysteresis as percentage of active power range
end

function modecontrol(
    mode::WattVARMode,
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
    
    # Normalize active power to percentage of reference
    activePowerPercent = (currentIterationPower / mode.activePowerReference) * 100.0
    
    # Get previous reactive power for hysteresis
    previousReactivePower = length(mode.params.modeWIP.value) > 0 ? mode.params.modeWIP.value[end] : 0.0
    
    # Evaluate watt-var curve with hysteresis
    hysteresisBand = mode.hysteresisPercent / 100.0 * mode.activePowerReference
    targetReactivePower = evaluate_curve_with_hysteresis(
        mode.wattVarCurve,
        activePowerPercent,
        previousReactivePower,
        hysteresisBand
    )
    
    # Apply reactive power limits
    constrainedReactivePower = max(min(targetReactivePower, mode.maximumReactivePower), mode.minimumReactivePower)
    
    return constrainedReactivePower
end
