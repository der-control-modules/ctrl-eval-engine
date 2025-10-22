using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: MesaController, RampParams, previous_WIP, apply_ramps, apply_energy_limits

"""
    UnderFrequencyEmergencyMode

Emergency mode activated during under-frequency conditions (Low Frequency Ride-Through).
Responds to grid frequency dropping below critical thresholds by injecting active power (discharging)
to help support system frequency.

Based on DNP3 AN-2018-001 specification for BESS emergency response.
"""
struct UnderFrequencyEmergencyMode <: MesaMode
    params::MesaModeParams
    frequencyThreshold::Float64  # Frequency threshold to trigger emergency response (Hz)
    responseGradient::Float64  # Active power response per frequency deviation (kW/Hz)
    maxEmergencyPower::Float64  # Maximum emergency power (kW, absolute value)
    rampParams::RampParams  # Ramp rate parameters
    maximumSOC::Float64  # Maximum SOC to allow discharging (%)
end

function modecontrol(
    mode::UnderFrequencyEmergencyMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries,
    currentIterationPower::Float64
)
    # TODO: Get current grid frequency measurement from system
    # currentFrequency = get_frequency_measurement(controller, t)
    currentFrequency = 60.0  # Placeholder - nominal frequency
    
    # Check if frequency is below threshold
    if currentFrequency >= mode.frequencyThreshold
        # No emergency response needed
        return 0.0
    end
    
    # Calculate frequency deviation below threshold
    frequencyDeviation = mode.frequencyThreshold - currentFrequency
    
    # Calculate emergency power response (positive for discharging to inject power)
    emergencyPower = min(mode.responseGradient * frequencyDeviation, mode.maxEmergencyPower)
    
    # Check SOC limits - don't discharge if below maximum SOC threshold
    currentSOC = (energy_state(ess) / e_max(ess)) * 100.0
    if currentSOC >= mode.maximumSOC
        return 0.0  # SOC too high, cannot inject more power
    end
    
    # Get previous power for ramping
    previousPower = previous_WIP(mode)
    
    # Apply ramp limits for smooth transition
    rampLimitedPower = apply_ramps(ess, mode.rampParams, previousPower, emergencyPower)
    
    # Apply ESS physical power limits
    essLimitedPower = max(min(rampLimitedPower, p_max(ess)), p_min(ess))
    
    # Apply energy limits to prevent over-discharging
    energyLimitedPower = apply_energy_limits(
        ess, 
        essLimitedPower, 
        Dates.Second(controller.resolution),
        nothing,  # No minimum reserve for emergency
        nothing   # No maximum reserve for emergency
    )
    
    return energyLimitedPower
end
