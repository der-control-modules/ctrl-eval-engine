
struct MockScheduler <: Scheduler
    resolution::Dates.Period
    interval::Dates.Period
    sleepSeconds::Float64
end

"""
    schedule(ess, scheduler, useCases, tStart)

Schedule the operation of `ess` with `scheduler` given `useCases` starting from `tStart`
"""
function schedule(ess, scheduler::MockScheduler, _, tStart::Dates.DateTime)
    scheduleLength = Int(ceil(scheduler.interval, scheduler.resolution) / scheduler.resolution)
    currentSchedule = rand(scheduleLength) .* (
        p_max(ess, scheduler.interval) - p_min(ess, scheduler.interval)
    ) .+ p_min(ess, scheduler.interval)

    sleep(scheduler.sleepSeconds)
    @debug "Schedule updated" tStart currentSchedule
    return Schedule(currentSchedule, scheduler.resolution)
end