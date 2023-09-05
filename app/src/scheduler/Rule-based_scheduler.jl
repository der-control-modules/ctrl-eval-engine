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
    price_comb = combinations(price_forecast,2)
    feasible_theta = []

    for p in 1:size(price_comb, 1)

        if price_comb[p,1] < price_comb[p,2]
            append!(feasible_theta, [[price_comb[p,1], price_comb[p,1]]]) 
        end
    end

    all_state_trans = zeros(size(price_forecast, 2),size(feasible_theta, 1))
    all_power = zeros(size(price_forecast, 2),size(feasible_theta, 1))
    all_total_cost = []

    for i in 1:size(feasible_theta, 1)
        theta_low = feasible_theta[i][1]
        theta_high = feasible_theta[i][2]

        stateK0 = SOC(ess)

        cost = [];
        output = [];
        day_hours = len(price)

        for h in 1:size(price_forecast, 2):

            if price_forecast[1,h] <= theta_low
                batt = min(p_max(ess), e_max(ess) * (1 - stateK0) / η) 
                stateK0 = stateK0 + (batt*η)/e_max(ess)
                cost_cal = -batt*price_forecast[1,h]
                append!(cost,cost_cal)
                output = -batt
            elseif price_forecast[1,h] >= theta_high
                batt = min(p_max(ess),max(0,(energy_state(ess) - e_min(ess))*η)) 
                stateK0 = stateK0 - batt/(e_max(ess)*η)
                cost_cal = batt*price_forecast[1,h]
                append!(cost,cost_cal)
                output = batt
            else:
                batt = 0
                stateK0 = stateK0
                cost_cal = batt*price_forecast[1,h]
                append!(cost,cost_cal)
                output = batt
            end
            all_state_trans[h,i] = stateK0
            all_power[h,i] = output 
        end
   
        append!(all_total_cost,sum(cost))
    end

    optimal_index  = getindex.(findall(all_total_cost .== maximum(all_total_cost)), [2])
    optimal_power = all_power[:,optimal_index]
    optimal_states = all_state_trans[:,optimal_index]
    

    # scheduledPower = average_power(schedulePeriod)

    # idxloadFollowing = findfirst(uc -> uc isa LoadFollowing, useCases)
    # if idxloadFollowing !== nothing
    #     ucLF::LoadFollowing = useCases[idxloadFollowing]
    #     forecastLoad, _, _ = CtrlEvalEngine.get_period(ucLF.forecastLoadPower, t)
    #     actualLoad, _, tEndActualLoad = CtrlEvalEngine.get_period(ucFL.realtimeLoadPower, t)
    #     theta_low = forecastLoad - controller.bound
    #     theta_high = forecastLoad + controller.bound
    #     η = sqrt(ηRT(ess))
    #     if actualLoad > theta_high
    #         batt = min(p_max(ess), max(0, (energy_state(ess) - e_min(ess)) * η))
    #         batt_power =
    #                 min(actualLoad - theta_high, batt)

    #     elseif actualLoad < theta_low
    #         batt = min(p_max(ess), e_max(ess) * (1 - SOC(ess)) / η)
    #         batt_power =
    #                 max(actualLoad - theta_low, -batt)

    #     else
    #         batt_power = 0
    #     end

    #     if batt_power < 0
    #         batt_soc = SOC(ess) - (batt_power * η) / e_max(ess)
    #     else
    #         batt_soc = SOC(ess) - batt_power / (e_max(ess) * η)
    #     end

    #     @debug "Rule-based RT controller exiting" batt_power
    #     return FixedIntervalTimeSeries([batt_power], tEndActualLoad - t)
    # else
    #     # Load Following isn't selected, follow schedule
    #     remainingTime = EnergyStorageScheduling.end_time(schedulePeriod) - t
    #     return FixedIntervalTimeSeries(
    #         [
    #             min(
    #                 max(p_min(ess, remainingTime), scheduledPower),
    #                 p_max(ess, remainingTime),
    #             ),
    #         ],
    #         remainingTime,
    #     )
    # end
end