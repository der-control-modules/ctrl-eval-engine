"""
    EnergyStorageScheduling

The `EnergyStorageScheduling` provides type and functions related to the scheduling/dispatch of energy storage systems.
"""
module EnergyStorageScheduling

using Dates

export get_scheduler, schedule

abstract type Scheduler end

struct Schedule
    powerKw::Vector{Float64}
    resolution::Dates.TimePeriod
end

Base.iterate(s::Schedule, index=1) = index > length(s.powerKw) ? nothing : ((s.powerKw[index], s.resolution), index + 1)
Base.eltype(::Type{Schedule}) = Tuple{Float64, Dates.TimePeriod}
Base.length(s::Schedule) = length(s.powerKw)

include("mock-scheduler.jl")

"""
    get_scheduler(inputDict::Dict)

Create a scheduler of appropriate type from the input dictionary
"""
function get_scheduler(inputDict::Dict)
    return MockScheduler(Hour(1), Hour(6))
end

end