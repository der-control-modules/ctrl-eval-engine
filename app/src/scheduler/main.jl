"""
    EnergyStorageScheduling

The `EnergyStorageScheduling` provides type and functions related to the scheduling/dispatch of energy storage systems.
"""
module EnergyStorageScheduling

using Dates
using CtrlEvalEngine: InvalidInput, FixedIntervalTimeSeries

export get_scheduler, schedule, Schedule, SchedulePeriod, SchedulePeriodProgress, duration, average_power

abstract type Scheduler end

struct Schedule
    powerKw::Vector{Float64}
    tStart::Dates.DateTime
    resolution::Dates.TimePeriod
end

struct SchedulePeriod
    powerKw::Float64
    tStart::Dates.DateTime
    duration::Dates.TimePeriod
end

duration(sp::SchedulePeriod) = sp.duration
start_time(sp::SchedulePeriod) = sp.tStart
end_time(sp::SchedulePeriod) = sp.tStart + sp.duration
average_power(sp::SchedulePeriod) = sp.powerKw

struct SchedulePeriodProgress
    t::Vector{Dates.DateTime}
    powerKw::Vector{Float64}
end

SchedulePeriodProgress(sp::SchedulePeriod) = SchedulePeriodProgress([start_time(sp)], [])

Base.iterate(s::Schedule, index=1) =
    index > length(s.powerKw) ?
    nothing :
    (
        SchedulePeriod(
            s.powerKw[index],
            s.tStart + s.resolution * (index - 1),
            s.resolution
        ),
        index + 1
    )

Base.eltype(::Type{Schedule}) = SchedulePeriod
Base.length(s::Schedule) = length(s.powerKw)

using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases

include("mock-scheduler.jl")
include("optimization-scheduler.jl")
include("mock-python-scheduler.jl")
include("manual-scheduler.jl")

"""
    get_scheduler(inputDict::Dict)

Create a scheduler of appropriate type from the input dictionary
"""
function get_scheduler(schedulerConfig::Dict)
    schedulerType = schedulerConfig["type"]
    scheduler = if schedulerType == "mock"
        MockScheduler(Hour(1), Hour(6), get(schedulerConfig, "sleepSeconds", 0))
    elseif schedulerType == "optimization"
        OptScheduler(Hour(1), Day(1), Day(1))
    else
        throw(InvalidInput("Invalid scheduler type: $schedulerType"))
    end
    return scheduler
end

end