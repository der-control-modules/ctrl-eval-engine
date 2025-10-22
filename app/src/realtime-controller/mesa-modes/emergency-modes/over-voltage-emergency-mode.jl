using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: MesaController, RampParams, previous_WIP, apply_ramps, apply_energy_limits

"""
    OverVoltageEmergencyMode

Emergency mode activated during over-voltage conditions (High Voltage Ride-Through).
Responds to grid voltage exceeding critical thresholds by absorbing active power (charging)
to help reduce system voltage.

Based on DNP3 AN-2018-001 specification for BESS emergency response.
"""
struct OverVoltageEmergencyMode <: MesaMode
    params::MesaModeParams
    criticalHighVoltage::Float64  # Voltage threshold to trigger emergency response (p.u.)
    responseGradient::Float64  # Active power response per voltage deviation (kW/p.u.)
    maxEmergencyPower::Float64  # Maximum emergency power (kW, absolute value)
    rampParams::RampParams  # Ramp rate parameters
    minimumSOC::Float64  # Minimum SOC to allow charging (%)
end

function modecontrol(
    mode::OverVoltageEmergencyMode,
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
    
    # Check if voltage exceeds critical high threshold
    if currentVoltage <= mode.criticalHighVoltage
        # No emergency response needed
        return 0.0
    end
    
    # Calculate voltage deviation above critical threshold
    voltageDeviation = currentVoltage - mode.criticalHighVoltage
    
    # Calculate emergency power response (negative for charging to absorb power)
    emergencyPowerMagnitude = min(mode.responseGradient * voltageDeviation, mode.maxEmergencyPower)
    emergencyPower = -emergencyPowerMagnitude  # Negative for charging
    
    # Check SOC limits - don't charge if above minimum SOC threshold
    currentSOC = (energy_state(ess) / e_max(ess)) * 100.0
    if currentSOC <= mode.minimumSOC
        return 0.0  # SOC too low, cannot absorb more power
    end
    
    # Get previous power for ramping
    previousPower = previous_WIP(mode)
    
    # Apply ramp limits for smooth transition
    rampLimitedPower = apply_ramps(ess, mode.rampParams, previousPower, emergencyPower)
    
    # Apply ESS physical power limits
    essLimitedPower = max(min(rampLimitedPower, p_max(ess)), p_min(ess))
    
    # Apply energy limits to prevent over-charging
    energyLimitedPower = apply_energy_limits(
        ess, 
        essLimitedPower, 
        Dates.Second(controller.resolution),
        nothing,  # No minimum reserve for emergency
        nothing   # No maximum reserve for emergency
    )
    
    return energyLimitedPower
end
