
struct MockController <: RTController
    resolution::Dates.Period
end

"""
    control(ess, mockController, schedule, useCases, t)

Return the series of operation of `ess` for the duration of the schedule according to `mockController` given `schedule` and `useCases`.
`t` is the timestamp.
"""
function control(_, mockController::MockController, schedule::Tuple{Float64,Dates.TimePeriod}, _, tStart)
    tEnd = tStart + ceil(schedule[2], mockController.resolution) - mockController.resolution
    controlOps = [
        schedule[1]
        for _ in tStart:mockController.resolution:tEnd
    ]
    @debug "RT control updated" controlOps
    return ControlOperations(
        controlOps,
        mockController.resolution
    )
end