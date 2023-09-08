"""
    TimeOfUseRuleSet

`TimeOfUseRuleSet` represents a set of target SoCs corresponding to ranges of price.
The target value is defined as `target[i]` during the `i`th price range (from `price[i]` to `price[i + 1]`),
where `1 ≤ i ≤ length(target)` and `length(price) == length(target) + 1`.
"""
struct TimeOfUseRuleSet
    price::Vector{Float64}
    target::Vector{Union{Float64, Nothing}}
#    TimeOfUseRuleSet(price, target) =
#        length(price) == length(target) + 1 ? new{eltype(target)}(price, target) : error("Incompatible lengths")
end

Base.iterate(rs::TimeOfUseRuleSet, index = 1) =
    index > length(rs.target) || index + 1 > length(rs.price) ? nothing :
    ((rs.target[index], rs.price[index], rs.price[index+1]), index + 1)

Base.eltype(::Type{TimeOfUseRuleSet}) = Tuple{Float64, Float64, Float64}  
Base.length(rs::TimeOfUseRuleSet) = min(length(rs.target), length(rs.price) - 1)

"""
    get_target(rs, price)

Return the target of `rs` at `price` and the defined price range that encloses `price`.
"""
get_target(rs::TimeOfUseRuleSet, price::Float64) = begin
    if price ≥ rs.price[1] && price < rs.price[end]
        index = findfirst(x -> x > price, rs.price) - 1
        (rs.target[index], rs.price[index], rs.price[index+1])
    elseif price < rs.price[1]
        (zero(eltype(rs.target)), nothing, rs.price[1])
    else
        (zero(eltype(rs.target)), rs.price[end], nothing)
    end
end

struct TimeOfUseScheduler <: Scheduler
    resolution::Dates.Period
    interval::Dates.Period
    rule_set::TimeOfUseRuleSet
end

"""
    schedule(ess, TimeOfUseScheduler, useCases, t)

Schedule the operation of `ess` with `TimeOfUseScheduler` given `useCases`
"""
function schedule(ess, scheduler::TimeOfUseScheduler, useCases::AbstractVector{<:UseCase}, tStart::Dates.DateTime)
    eaIdx = findfirst(uc -> uc isa EnergyArbitrage, useCases)
    if isnothing(eaIdx)
        error("No supported use case is found by TimeOfUseScheduler")
    end
    useCase = useCases[eaIdx]
    scheduleLength = Int(ceil(scheduler.interval, scheduler.resolution) / scheduler.resolution)
    current_soc = SOC(ess)
    schedule_vector = Vector{Float64}(undef, scheduleLength)
    soc_vector = Vector{Float64}(undef, scheduleLength)
    for i = 1:scheduleLength
        step_start = tStart + (scheduler.resolution * (i - 1))
        price, _, tou_end = get_period(useCase.price, step_start)
        target, _, _ = get_target(scheduler.rule_set, price)
        target = isnothing(target) ? current_soc : target / 100.0
        # TODO: This should really get the target for all periods of the use case so that it can determine when the next __change__ in the mode is, rather than assuming each period to be atomic.
        efficiency = current_soc >= target ? ess.specs.C_p : ess.specs.C_n
        energy_change = ((current_soc - target) * ess.specs.energyCapacityKwh) / -efficiency # * 100)
        schedule_vector[i] = scheduled_power = energy_change / ((tou_end - step_start) / Dates.Second(1))
        soc_vector[i] = current_soc = current_soc + (energy_change * efficiency / ess.specs.energyCapacityKwh)
    end
    return Schedule(schedule_vector, tStart, scheduler.resolution, soc_vector, zeros(scheduleLength))
end
