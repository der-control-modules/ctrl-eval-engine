
struct MockScheduler <: Scheduler
    resolution::Dates.Period
    interval::Dates.Period
    sleepSeconds::Float64
end

"""
    schedule(ess, mockScheduler, useCases, t)

Schedule the operation of `ess` with `mockScheduler` given `useCases`
"""
function schedule(ess, mockScheduler::MockScheduler, _, tStart::Dates.DateTime)
    scheduleLength = Int(ceil(mockScheduler.interval, mockScheduler.resolution) / mockScheduler.resolution)
    currentSchedule = rand(scheduleLength) .* (
        p_max(ess, mockScheduler.interval) - p_min(ess, mockScheduler.interval)
    ) .+ p_min(ess, mockScheduler.interval)

    sleep(mockScheduler.sleepSeconds)
    @debug "Schedule updated" tStart currentSchedule
    return Schedule(currentSchedule, mockScheduler.resolution)
end