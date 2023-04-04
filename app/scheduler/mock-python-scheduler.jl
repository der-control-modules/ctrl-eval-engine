
using PyCall

struct MockPyScheduler <: Scheduler
    resolution::Dates.Period
    interval::Dates.Period
    sleepSeconds::Float64
end

pushfirst!(pyimport("sys")."path", @__DIR__)
py_mock_scheduler = pyimport("mock-python-scheduler")

function schedule(ess, scheduler::MockPyScheduler, useCases, tStart::Dates.DateTime)
    scheduleLength = Int(ceil(mockScheduler.interval, mockScheduler.resolution) / mockScheduler.resolution)
    currentSchedule = py_mock_scheduler.mock_schedule(scheduleLength)
    sleep(scheduler.sleepSeconds)
    return Schedule(currentSchedule, scheduler.resolution)
end