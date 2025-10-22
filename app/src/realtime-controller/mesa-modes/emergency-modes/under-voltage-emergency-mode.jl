using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: MesaController, RampParams, previous_WIP, apply_ramps, apply_energy_limits

"""
    UnderVoltageEmergencyMode

Emergency mode activated during under-voltage conditions (Low Voltage Ride-Through).
Responds to grid voltage dropping below critical thresholds by injecting active power (discharging)
to help support system voltage.

Based on DNP3 AN-2018-001 specification for BESS emergency response.
"""
struct UnderVoltageEmergencyMode <: MesaMode
    params::MesaModeParams
    criticalLowVoltage::Float64  # Voltage threshold to trigger emergency response (p.u.)
    responseGradient::Float64  # Active power response per voltage deviation (kW/p.u.)
    maxEmergencyPower::Float64  # Maximum emergency power (kW, absolute value)
    rampParams::RampParams  # Ramp rate parameters
    maximumSOC::Float64  # Maximum SOC to allow discharging (%)
end

function modecontrol(
    mode::UnderVoltageEmergencyMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries,
    currentIterationPower::Float64
)
    # TODO: Get current voltage measurement from system
    # currentVoltage = get_voltage_measurement(controller, t)
    currentVoltage = 1.0  # Placeholder - nominal voltage
    
    # Check if voltage is below critical low threshold
    if currentVoltage >= mode.criticalLowVoltage
        # No emergency response needed
        return 0.0
    end
    
    # Calculate voltage deviation below critical threshold
    voltageDeviation = mode.criticalLowVoltage - currentVoltage
    
    # Calculate emergency power response (positive for discharging to inject power)
    emergencyPower = min(mode.responseGradient * voltageDeviation, mode.maxEmergencyPower)
    
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
