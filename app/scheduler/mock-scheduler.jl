
struct MockScheduler <: Scheduler
    resolution::Dates.Period
    interval::Dates.Period
end

"""
    schedule(ess, mockScheduler, useCases, t)

Schedule the operation of `ess` with `mockScheduler` given `useCases`
"""
function schedule(ess, mockScheduler::MockScheduler, _, tStart::Dates.DateTime)
    scheduleLength = Int(ceil(mockScheduler.interval, mockScheduler.resolution) / mockScheduler.resolution)
    currentSchedule = (rand(scheduleLength) .- 0.5) .* ess.specs.powerCapacityKw ./ 5
    @debug "Schedule updated" tStart currentSchedule
    return Schedule(currentSchedule, mockScheduler.resolution)
end