
struct MockController <: RTController
    resolution::Dates.Period
end

function control(_, mockController::MockController, schedulePeriod::SchedulePeriod, _, t, _)
    tEnd = t + ceil(end_time(schedulePeriod) - t, mockController.resolution) - mockController.resolution
    controlOps = [
        average_power(schedulePeriod)
        for _ in t:mockController.resolution:tEnd
    ]
    @debug "Control sequence updated" controlOps
    return ControlSequence(
        controlOps,
        mockController.resolution
    )
end