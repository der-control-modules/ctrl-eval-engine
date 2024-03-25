using Combinatorics

struct RuleBasedScheduler <: Scheduler
    resolution::Dates.Period
    interval::Dates.Period
end

#RuleBasedScheduler(config::Dict) = RuleBasedScheduler(max(0, config["loadBound"]))

function schedule(
    ess::EnergyStorageSystem,
    scheduler::RuleBasedScheduler,
    useCases::AbstractArray{<:UseCase},
    tStart::DateTime,
)
    scheduleLength =
        Int(ceil(scheduler.interval, scheduler.resolution) / scheduler.resolution)

    eaIdx = findfirst(uc -> uc isa EnergyArbitrage, useCases)
    if isnothing(eaIdx)
        error("No supported use case is found by Rule-based scheduler")
    end
    ucEA = useCases[eaIdx]

    price = sample(
        forecast_price(ucEA),
        range(
            tStart;
            step = scheduler.resolution,
            length = scheduleLength,
        ),
    )

    feasible_theta = [comb for comb in combinations(price, 2) if comb[1] < comb[2]]
    all_state_trans = zeros(scheduleLength, length(feasible_theta)) #size(price_forecast, 2)
    all_power = zeros(scheduleLength, length(feasible_theta))
    all_total_cost = zeros(length(feasible_theta))

    for i in eachindex(feasible_theta)
        theta_low = feasible_theta[i][1]
        theta_high = feasible_theta[i][2]
        stateK0 = SOC(ess)
        cost = zeros(scheduleLength)

        for h = 1:scheduleLength
            if price[h] <= theta_low
                batt = min(p_max(ess), e_max(ess) * (1 - stateK0) / ηRT(ess))
                stateK0 = stateK0 + (batt * ηRT(ess)) / e_max(ess)
                cost_cal = -batt * price[h]
                output = -batt
            elseif price[h] >= theta_high
                batt = min(p_max(ess), max(0, (stateK0 * e_max(ess) - e_min(ess)) * ηRT(ess)))
                stateK0 = stateK0 - batt / (e_max(ess) * ηRT(ess))
                cost_cal = batt * price[h]
                output = batt
            else
                batt = 0
                stateK0 = stateK0
                cost_cal = batt * price[h]
                output = batt
            end
            cost[h] = cost_cal
            all_state_trans[h, i] = stateK0
            all_power[h, i] = output
        end

        all_total_cost[i] = sum(cost)
    end

    _, optimal_index = findmax(all_total_cost)
    optimal_power = all_power[:, optimal_index]
    optimal_states = all_state_trans[:, optimal_index]

    return Schedule(
        optimal_power,
        tStart;
        resolution = scheduler.resolution,
        SOC = [SOC(ess), optimal_states...],
    )
end