struct RuleBasedController <: RTController
    bound::Float64
end

RuleBasedController(config::Dict) = RuleBasedController(max(0, config["loadBound"]))

function control(
    ess::EnergyStorageSystem,
    controller::RuleBasedController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractArray{<:UseCase},
    t::DateTime,
    _,
)
    scheduledPower = average_power(schedulePeriod)

    idxloadFollowing = findfirst(uc -> uc isa LoadFollowing, useCases)
    if idxloadFollowing !== nothing
        ucLF::LoadFollowing = useCases[idxloadFollowing]
        forecastLoad, _, tEndForecstLoad =
            CtrlEvalEngine.get_period(ucLF.forecastLoadPower, t)
        actualLoad, _, tEndActualLoad = CtrlEvalEngine.get_period(ucLF.realtimeLoadPower, t)
        tCtrlPeriodEnd =
            isnothing(tEndActualLoad) || isnothing(tEndForecstLoad) ?
            end_time(schedulePeriod) : min(tEndForecstLoad, tEndActualLoad)
        theta_low = forecastLoad - controller.bound
        theta_high = forecastLoad + controller.bound
        η = sqrt(ηRT(ess))
        batt_power = if actualLoad > theta_high
            min(
                p_max(ess),
                max(0, min(actualLoad - theta_high, (energy_state(ess) - e_min(ess)) * η)),
            )
        elseif actualLoad < theta_low
            max(
                p_min(ess),
                min(0, max(actualLoad - theta_low, -e_max(ess) * (1 - SOC(ess)) / η)),
            )
        else
            0
        end

        @debug "Rule-based RT controller exiting" batt_power
        return FixedIntervalTimeSeries(t, tCtrlPeriodEnd - t, [batt_power])
    else
        # Load Following isn't selected, follow schedule
        idxReg = findfirst(uc -> uc isa Regulation, useCases)
        if idxReg !== nothing
            # Regulation is selected
            ucReg::Regulation = useCases[idxReg]
            regCap = regulation_capacity(schedulePeriod)
            return FixedIntervalTimeSeries(t, remainingTime, [scheduled_bess_power]) +
                   extract(ucReg.AGCSignalPu, t, end_time(schedulePeriod)) * regCap
        else
            remainingTime = end_time(schedulePeriod) - t
            return FixedIntervalTimeSeries(
                t,
                remainingTime,
                [
                    min(
                        max(p_min(ess, remainingTime), scheduledPower),
                        p_max(ess, remainingTime),
                    ),
                ],
            )
        end
    end
end