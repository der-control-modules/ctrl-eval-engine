
struct PassThroughController <: RTController
    resolution::Dates.Period
end

function control(_, PassThroughController::PassThroughController, schedulePeriod::SchedulePeriod, _, t, _)
    tEnd = t + ceil(EnergyStorageScheduling.end_time(schedulePeriod) - t, PassThroughController.resolution) - PassThroughController.resolution
    controlOps = [
        average_power(schedulePeriod)
        for _ in t:PassThroughController.resolution:tEnd
    ]
    @debug "Control sequence updated" controlOps
    return ControlSequence(
        controlOps,
        PassThroughController.resolution
    )
end