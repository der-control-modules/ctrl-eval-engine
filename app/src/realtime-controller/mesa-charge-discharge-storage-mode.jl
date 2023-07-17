using MesaEss: MesaController, VertexCurve, RampParams

struct ChargeDischargeStorageMode <: MesaMode
    rampOrTimeConstant::Bool
    rampParams::RampParams
    minimumReservePercent::Float64
    maximumReservePercent::Float64
    activePowerTarget::Float64
    modeWIP::FixedIntervalTimeSeries
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
    targetPower = mode.activePowerTarget >= 0 ? mode.activePowerTarget * p_max(ess) / 100 : mode.activePowerTarget * p_min(ess) / 100
    ramping_func = controller.rampOrTimeConstant ? apply_ramps : apply_time_constants
    tEnd = t + ceil(EnergyStorageScheduling.end_time(schedulePeriod) - t, controller.resolution) - controller.resolution
    for _ in t:controller.resolution:tEnd
        lastModePower = last(mode.modeWIP)
        rampLimitedPower = ramping_func(ess, mode.rampParams, lastModePower, targetPower)
        energyLimitedPower = apply_energy_limits(ess, rampLimitedPower, Dates.Second(controller.resolution),
                controller.minimumReservePercent, controller.maximumReservePercent)
        append!(mode.modeWIP, energyLimitedPower)
        controller.wip.value[i] = energyLimitedPower + controller.wip.value[i]
    end
end