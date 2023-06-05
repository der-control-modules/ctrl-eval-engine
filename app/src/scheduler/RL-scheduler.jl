
using PyCall


struct RLScheduler <: Scheduler
    resolution::Dates.Period
    approach::String
    numIter::UInt
end


function RLScheduler(config::Dict)
    RLScheduler(Hour(1), config["approach"], config["interation"])
end

function schedule(ess, rlScheduler::RLScheduler, useCases::AbstractArray{UseCase}, tStart::Dates.DateTime)
    pushfirst!(PyVector(pyimport("sys").path), ".")
    pyRL = pyimport("RL").RL
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
        "initial_soc" => SOC(ess)
    )

    K = 24
    K_interval = 1
    rlParameters = Dict(
        "epsilon_initial" => 0.7,
        "epsilon_interval" => 50 * K / 24,
        "epsilon_update" => 1.07,
        "alpha" => 1,
        "gamma" => 1,
        "discrete" => 20
    )

    price = sample(ucEA.price, range(tStart; step=Hour(1), length=K))
    _, _, battery_power = pyRL(
        price,
        "energy_arbitrage",
        rlScheduler.approach,
        batteryParameters,
        rlScheduler.numIter,
        K,
        K_interval
    )
    return Schedule(battery_power, tStart, rlScheduler.resolution)
end