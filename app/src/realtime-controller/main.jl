"""
    EnergyStorageRTControl

The `EnergyStorageRTControl` provides type and functions related to the realtime control of energy storage systems.
"""
module EnergyStorageRTControl

using Dates
using CtrlEvalEngine.EnergyStorageScheduling
using CtrlEvalEngine.EnergyStorageUseCases

export get_rt_controller, control

abstract type RTController end

struct ControlSequence
    powerKw::Vector{Float64}
    resolution::Dates.TimePeriod
end

Base.iterate(ops::ControlSequence, index=1) = index > length(ops.powerKw) ? nothing : ((ops.powerKw[index], ops.resolution), index + 1)
Base.eltype(::Type{ControlSequence}) = Tuple{Float64,Dates.TimePeriod}
Base.length(ops::ControlSequence) = length(ops.powerKw)

"""
    control(ess, controller, schedulePeriod, useCases, t, spProgress=nothing)

Return a control sequence of `ess`
for the `schedulePeriod`
according to `controller`
considering `useCases`,
where `t` is the current timestamp and
`spProgress` is the cumulative progress in the `schedulePeriod` leading up to `t`.

The returned control sequence, which may or may not cover the entire/remaining time in `schedulePeriod`, 
will be executed before calling this function again with updated ESS states and `spProgress`.
"""
control(
    ess,
    controller::RTController,
    schedulePeriod::SchedulePeriod,
    useCases,
    t=start_time(schedulePeriod),
    spProgress=nothing
) = control(ess, controller, schedulePeriod, useCases, t, spProgress)


include("mock-rt-controller.jl")
include("amac.jl")

"""
    get_rt_controller(inputDict::Dict)

Create a realtime controller of appropriate type from the input dictionary
"""
function get_rt_controller(controlConfig::Dict, ess, useCases)
    controlType = controlConfig["type"]
    controller = if controlType == "amac"
        AMAController(controlConfig, ess, useCases)
    else
        MockController(Minute(15))
    end

    return controller
end

end