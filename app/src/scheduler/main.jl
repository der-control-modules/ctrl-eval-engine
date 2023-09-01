"""
    EnergyStorageScheduling

The `EnergyStorageScheduling` provides type and functions related to the scheduling/dispatch of energy storage systems.
"""
module EnergyStorageScheduling

using Dates
using PyCall
using ..CtrlEvalEngine

export get_scheduler,
    schedule,
    Schedule,
    SchedulePeriod,
    SchedulePeriodProgress,
    duration,
    average_power,
    ending_soc,
    OptScheduler,
    RLScheduler

abstract type Scheduler end

struct Schedule
    powerKw::Vector{Float64}
    tStart::Dates.DateTime
    resolution::Dates.TimePeriod
    soc::Vector{Float64}
end

struct SchedulePeriod
    powerKw::Float64
    tStart::Dates.DateTime
    duration::Dates.TimePeriod
    socStart::Float64
    socEnd::Float64
end

duration(sp::SchedulePeriod) = sp.duration
CtrlEvalEngine.start_time(sp::SchedulePeriod) = sp.tStart
CtrlEvalEngine.end_time(sp::SchedulePeriod) = sp.tStart + sp.duration
average_power(sp::SchedulePeriod) = sp.powerKw
ending_soc(sp::SchedulePeriod) = sp.socEnd

Base.iterate(s::Schedule, index = 1) =
    index > length(s.powerKw) ? nothing :
    (
        SchedulePeriod(
            s.powerKw[index],
            s.tStart + s.resolution * (index - 1),
            s.resolution,
            s.soc[index],
            s.soc[index+1],
        ),
        index + 1,
    )

Base.eltype(::Type{Schedule}) = SchedulePeriod
Base.length(s::Schedule) = length(s.powerKw)

using ..CtrlEvalEngine.EnergyStorageSimulators
using ..CtrlEvalEngine.EnergyStorageUseCases

include("mock-scheduler.jl")
include("optimization-scheduler.jl")
include("mock-python-scheduler.jl")
include("manual-scheduler.jl")
include("RL-scheduler.jl")

struct IdleScheduler <: Scheduler
    interval::Dates.Period
end

schedule(ess::EnergyStorageSystem, scheduler::IdleScheduler, _, tStart::Dates.DateTime) =
    Schedule([0], tStart, scheduler.interval, [SOC(ess), SOC(ess)])

"""
    get_scheduler(inputDict::Dict)

Create a scheduler of appropriate type from the input dictionary
"""
function get_scheduler(schedulerConfig::Dict)
    schedulerType = schedulerConfig["type"]
    scheduler = if schedulerType == "mock"
        MockScheduler(Hour(1), Hour(6), get(schedulerConfig, "sleepSeconds", 0))
    elseif schedulerType == "optimization"
        endSocInput = get(schedulerConfig, "endSocPct", nothing)
        endSoc = if isnothing(endSocInput)
            nothing
        elseif endSocInput isa Real
            endSocInput / 100
        else
            (endSocInput[1], endSocInput[2]) ./ 100
        end
        res = Minute(
            round(
                Int,
                convert(Minute, Hour(1)).value * schedulerConfig["scheduleResolutionHrs"],
            ),
        )
        interval = Minute(
            round(Int, convert(Minute, Hour(1)).value * schedulerConfig["intervalHrs"]),
        )
        powerLimitPct = get(schedulerConfig, "powerLimitPct", 100)
        if isnothing(powerLimitPct)
            powerLimitPct = 100
        end
        OptScheduler(
            res,
            interval,
            ceil(
                Int64,
                schedulerConfig["optWindowLenHrs"] /
                schedulerConfig["scheduleResolutionHrs"],
            ),
            endSoc;
            minNetLoadKw = get(schedulerConfig, "minNetLoadKw", nothing),
            powerLimitPu = powerLimitPct / 100,
        )
    elseif schedulerType == "ml"
        res = Minute(
            round(
                Int,
                convert(Minute, Hour(1)).value *
                get(schedulerConfig, "scheduleResolutionHrs", 1),
            ),
        )
        RLScheduler(
            res,
            schedulerConfig["approach"],
            round(Int, get(schedulerConfig, "iteration", 4000)),
        )
    elseif schedulerType == "idle"
        IdleScheduler(Hour(24))
    else
        throw(InvalidInput("Invalid scheduler type: $schedulerType"))
    end
    return scheduler
end

function __init__()
    @pyinclude(joinpath(@__DIR__, "RL.py"))
end

end