
struct RLScheduler <: Scheduler
    resolution::Dates.Period
    approach::String
    epsilonUpdate::Float64
    numIter::UInt
end

function RLScheduler(res::Dates.Period, config::Dict)
    RLScheduler(
        res,
        config["approach"],
        get(config, "epsilonUpdate", 1.07),
        round(UInt, get(config, "iteration", 4000)),
    )
end

function schedule(
    ess,
    rlScheduler::RLScheduler,
    useCases::AbstractVector{<:UseCase},
    tStart::Dates.DateTime,
)
    eaIdx = findfirst(uc -> uc isa EnergyArbitrage, useCases)
    if isnothing(eaIdx)
        error("No supported use case is found by ML scheduler")
    end
    ucEA = useCases[eaIdx]
    batteryParameters = Dict(
        "energy" => e_max(ess),
        "power" => p_max(ess),
        "efficiency" => ηRT(ess),
        "soc_low" => e_min(ess) / e_max(ess),
        "soc_high" => 1,
        "initial_soc" => SOC(ess),
    )

    price = sample(
        ucEA.price,
        range(
            tStart;
            step = rlScheduler.resolution,
            stop = tStart + Hour(24) - Millisecond(1),
        ),
    )
    @debug "RL-scheduler" t = tStart resolution = rlScheduler.resolution price batteryParameters
    _, batterySocs, battery_power = py"RL"(
        price,
        "energy_arbitrage",
        rlScheduler.approach,
        /(promote(rlScheduler.resolution, Hour(1))...),
        batteryParameters,
        rlScheduler.numIter,
        rlScheduler.epsilonUpdate
    )
    return Schedule(
        -battery_power,
        tStart;
        resolution = rlScheduler.resolution,
        SOC = [SOC(ess), batterySocs...],
    )
end