

struct RLScheduler <: Scheduler
    resolution::Dates.Period
    approach::String
    numIter::UInt
end


function RLScheduler(config::Dict)
    RLScheduler(Hour(1), config["approach"], config["interation"])
end

function schedule(ess, rlScheduler::RLScheduler, useCases::AbstractVector{<:UseCase}, tStart::Dates.DateTime)
    eaIdx = findfirst(uc -> uc isa EnergyArbitrage, useCases)
    if isnothing(eaIdx)
        error("No supported use case is found by ML scheduler")
    end
    ucEA = useCases[eaIdx]
    batteryParameters = Dict(
        "energy" => e_max(ess),
        "power" => p_max(ess),
        "efficiency" => ηRT(ess),
        "soc_low" => e_min(ess) / e_max(ess) * 100,
        "soc_high" => 100,
        "initial_soc" => SOC(ess) * 100
    )

    price = sample(
        ucEA.price,
        range(
            tStart;
            step=rlScheduler.resolution,
            stop=tStart + Hour(24) - Second(1)
        )
    )
    _, _, battery_power = py"RL"(
        price,
        "energy_arbitrage",
        rlScheduler.approach,
        batteryParameters,
        rlScheduler.numIter
    )
    return Schedule(battery_power, tStart, rlScheduler.resolution)
end