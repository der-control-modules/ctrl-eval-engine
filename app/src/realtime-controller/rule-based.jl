struct RuleBasedController <: RTController
    bound::Float64
end

RuleBasedController(config::Dict) = RuleBasedController(max(0, config["bound"]))

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
        forecastLoad, _, _ = CtrlEvalEngine.get_period(ucLF.forecastLoadPower, t)
        actualLoad, _, tEndActualLoad = CtrlEvalEngine.get_period(ucFL.realtimeLoadPower, t)
        theta_low = forecastLoad - controller.bound
        theta_high = forecastLoad + controller.bound
        η = sqrt(ηRT(ess))
        if actualLoad > theta_high
            if scheduledPower < 0
                charging_power = scheduledPower
                discharging_power = 0
                batt = min(p_max(ess), max(0, (energy_state(ess) - e_min(ess)) * η))
                batt_power =
                    min(charging_power + discharging_power + actualLoad - theta_high, batt)
                if batt_power < 0
                    batt_soc = SOC(ess) + (-batt_power * η) / e_max(ess)
                else
                    batt_soc = SOC(ess) - batt_power / (e_max(ess) * η)
                end
            else
                charging_power = 0
                discharging_power = scheduledPower
                batt = min(p_max(ess), max(0, (energy_state(ess) - e_min(ess)) * η))
                batt_power =
                    min(charging_power + discharging_power + actualLoad - theta_high, batt)
                if batt_power < 0
                    batt_soc = SOC(ess) + (-batt_power * η) / e_max(ess)
                else
                    batt_soc = SOC(ess) - batt_power / (e_max(ess) * η)
                end
            end
        elseif actualLoad < theta_low
            if scheduledPower < 0
                charging_power = scheduledPower
                discharging_power = 0
                batt = min(p_max(ess), e_max(ess) * (1 - SOC(ess)) / η)
                batt_power =
                    max(charging_power + discharging_power + actualLoad - theta_low, -batt)
                if batt_power < 0
                    batt_soc = SOC(ess) + (-batt_power * η) / e_max(ess)
                else
                    batt_soc = SOC(ess) - batt_power / (e_max(ess) * η)
                end
            else
                charging_power = 0
                discharging_power = scheduledPower
                batt = min(p_max(ess), e_max(ess) * (1 - SOC(ess)) / η)
                batt_power =
                    max(charging_power + discharging_power + actualLoad - theta_low, -batt)
                if batt_power < 0
                    batt_soc = SOC(ess) + (-batt_power * η) / e_max(ess)
                else
                    batt_soc = SOC(ess) - batt_power / (e_max(ess) * η)
                end
            end
        else
            if scheduledPower < 0
                charging_power = scheduledPower
                discharging_power = 0
                batt = min(p_max(ess), e_max(ess) * (1 - SOC(ess)) / η)
                batt_power = max(charging_power + discharging_power, -batt)
                batt_soc = SOC(ess) + (-batt_power * η) / e_max(ess)
            else
                charging_power = 0
                discharging_power = scheduledPower
                batt = min(
                    p_max(ess),
                    max(0, (SOC(ess) - e_min(ess) / e_max(ess)) * e_max(ess) * η),
                )
                batt_power = min(charging_power + discharging_power, batt)
                batt_soc = SOC(ess) - batt_power / (e_max(ess) * η)
            end
        end
        @debug "Rule-based RT controller exiting" batt_power
        return ControlSequence([batt_power], tEndActualLoad - t)
    else
        # Load Following isn't selected, follow schedule
        remainingTime = EnergyStorageScheduling.end_time(schedulePeriod) - t
        return ControlSequence(
            [
                min(
                    max(p_min(ess, remainingTime), scheduledPower),
                    p_max(ess, remainingTime),
                ),
            ],
            remainingTime,
        )
    end
end