module MesaEss

    using Dates
    using CtrlEvalEngine.EnergyStorageSimulators
    using CtrlEvalEngine.EnergyStorageUseCases: UseCase, LoadFollowing
    using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod

    struct MesaMode
        priority::Int
        timeWindow::Dates.Second
        rampTime::Dates.Second
        reversionTimeout::Dates.Second
    end

    struct MesaController <: RTController
        modes::Vector{MesaMode}
        resolution::Dates.Period
        wip::FixedIntervalTimeSeries
    end

    function MesaController(modes, resolution)
        wip = FixedIntervalTimeSeries([], resolution)
        return MesaController(modes, resolution, wip)
    end

    struct Vertex
        x::Float64
        y::Float64
    end

    struct VertexCurve
        vertices::Array{Vertex}
    end 

    struct RampParams
        rampUpTimeConstant::Dates.Second
        rampDownTimeConstant::Dates.Second
        dischargeRampUpRate::Float64  # The ramp rates are in units of a tenth of a percent per second -- i.e. divide by 1000 in constructor to get and store multiplier.
        dischargeRampDownRate::Float64
        chargeRampUpRate::Float64
        chargeRampDownRate::Float64
    end

    function apply_time_constants(
        ess::EnergyStorageSystem,
        rampParams::Float64,
        currentPower::Float64,
        targetPower::Float64
    )
        # Using time constants, not ramps.
        # timeSinceStart = currentTime - startTime
        # timeUntilEnd = endTime - currentTime
        allowedPowerChange = 0.0
        return currentPower + allowedPowerChange
    end

    function apply_ramps(
        ess::EnergyStorageSystem,
        rampParams::RampParams,
        currentPower::Float64,
        targetPower::Float64, 
        )

        # TODO: Assuming ramp rate is percentage per second of p_max or p_min. The actual units in DNP3 spec are just percent per second. 
        #        Should this be percent of requested jump in power per second instead?
        if targetPower > currentPower & targetPower >= 0  # TODO: This assumes percent per second refers to percent of max/min power.
            allowedPowerChange = min(targetPower - current_power, rampParams.dischargeRampUpRate * p_max(ess))
        elseif targetPower < currentPower & targetPower >= 0
            allowedPowerChange = min(targetPower - current_power, rampParams.dischargeRampDownRate * p_max(ess))
        elseif targetPower > currentPower & targetPower < 0
            allowedPowerChange = max(targetPower - current_power, rampParams.chargeRampUpRate * p_min(ess))
        elseif targetPower < currentPower & targetPower < 0
            allowedPowerChange = max(targetPower - current_power, rampParams.chargeRampDownRate * p_min(ess))
        else
            allowedPowerChange = 0.0
        end
        return currentPower + allowedPowerChange
    end

    function apply_energy_limits(
        ess::EnergyStorageSystem,
        power::Float64,
        duration::Dates.Period, 
        minReserve::Float64=nothing, 
        maxReserve::Float64=nothing
        )
        minEnergy = minReserve ≠ nothing ? minReserve * e_max(ess) : e_min(ess)
        maxEnergy = maxReserve ≠ nothing ? maxReserve * e_max(ess) : e_max(ess)
        proposedNewEnergy = energy_state(ess) + power * duration
        if proposedNewEnergy > maxEnergy
            return (maxEnergy - energy_state(ess)) / duration
        elseif proposedNewEnergy < minEnergy
            return (minEnergy - energy_state(ess)) / duration
        else
            return power
        end
    end

    function control(
        ess::EnergyStorageSystem,
        controller::MesaController,
        schedulePeriod::SchedulePeriod,
        useCases::AbstractVector{<:UseCase},
        t::Dates.DateTime,
        spProgress::VariableIntervalTimeSeries,
    )
        # TODO: Implement handling of shared parameters which all modes have.
        # TODO: Initialize WIP struct based on schedulePeriod and/or schedulePeriodProgress. (should probably be FixedIntervalTimeSeries.)
        sort!(controller.modes, by=m->m.priority)
        for mode in controller.modes
            modecontrol(mode, ess, controller, schedulePeriod, useCases, t, spProgress)
        end
        for (i, p) in enumerate(controller.wip.value)
            essLimitedPower = min(max(p, p_min(ess)), p_max(ess))
            energyLimitedPower = apply_energy_limits(ess, essLimitedPower, Dates.Second(controller.resolution))
            controller.wip.value[i] = energyLimitedPower
        end
        return ControlSequence(controller.wip)
    end
end