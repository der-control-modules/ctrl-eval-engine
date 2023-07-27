using CtrlEvalEngine.EnergyStorageRTControl: MesaController, VertexCurve, RampParams

struct ChargeDischargeStorageMode <: MesaMode
    params::MesaModeParams
    rampOrTimeConstant::Bool
    rampParams::RampParams
    minimumReservePercent::Float64
    maximumReservePercent::Float64
    activePowerTarget::Float64
end

function modecontrol(
    mode::ChargeDischargeStorageMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    _,
    t::Dates.DateTime,
    _
)
    # Use specified target if it exists, otherwise, use the current SchedulePeriod power.
    # TODO: Should we just use the SchedulePeriod power, and not have an input to specify a power at all?
    activePowerTarget = mode.activePowerTarget === nothing ? get_period(schedulePeriod, t) : mode.activePowerTarget
    
    # Constrain target by storage limits.
    targetPower = activePowerTarget >= 0 ? activePowerTarget * p_max(ess) / 100 : activePowerTarget * p_min(ess) / 100

    # Move towards the target power as approprate to time constant or ramp rate limits:
    ramping_func = controller.rampOrTimeConstant ? apply_ramps : apply_time_constants
    lastModePower = last(mode.params.modeWIP.value)
    rampLimitedPower = ramping_func(ess, mode.rampParams, lastModePower, targetPower)
    
    # Apply mode-specific energy limits.
    energyLimitedPower = apply_energy_limits(ess, rampLimitedPower, Dates.Second(controller.resolution),
            controller.minimumReservePercent, controller.maximumReservePercent)
    return energyLimitedPower
end
