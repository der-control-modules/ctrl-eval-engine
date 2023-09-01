
struct PassThroughController <: RTController
    resolution::Dates.Period
end

function control(
    _,
    controller::PassThroughController,
    schedulePeriod::SchedulePeriod,
    _,
    t,
    _,
)
    tEnd =
        t + ceil(end_time(schedulePeriod) - t, controller.resolution) -
        controller.resolution
    controlOps = [average_power(schedulePeriod) for _ = t:controller.resolution:tEnd]
    @debug "Control sequence updated" controlOps
    return ControlSequence(controlOps, controller.resolution)
end