"""
    EnergyStorageRTControl

The `EnergyStorageRTControl` provides type and functions related to the realtime control of energy storage systems.
"""
module EnergyStorageRTControl

using CtrlEvalEngine
using Dates
using PyCall
using CtrlEvalEngine.EnergyStorageScheduling
using CtrlEvalEngine.EnergyStorageUseCases
using CtrlEvalEngine.EnergyStorageSimulators

export get_rt_controller, control, PIDController, AMAController

abstract type RTController end

struct ControlSequence
    powerKw::Vector{Float64}
    resolution::Dates.TimePeriod
end

Base.iterate(ops::ControlSequence, index = 1) =
    index > length(ops.powerKw) ? nothing :
    ((ops.powerKw[index], ops.resolution), index + 1)
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
control(ess, controller::RTController, schedulePeriod::SchedulePeriod, useCases) =
    control(ess, controller, schedulePeriod, useCases, start_time(schedulePeriod), nothing)

include("mock-rt-controller.jl")
include("pid.jl")
include("amac.jl")

"""
    get_rt_controller(inputDict::Dict, ess::EnergyStorageSystem, useCases::AbstractArray{<:UseCase})

Create a realtime controller of appropriate type from the input dictionary
"""
function get_rt_controller(
    config::Dict,
    ess::EnergyStorageSystem,
    useCases::AbstractArray{<:UseCase},
)
    controllerType = config["type"]
    res = Millisecond(
        round(
            Int,
            convert(Millisecond, Second(1)).value * get(config, "resolutionSec", 60),
        ),
    )
    controller = if controllerType == "mock"
        MockController(res)
    elseif controllerType == "pid"
        PIDController(res, config["Kp"], config["Ti"], config["Td"])
    elseif controllerType == "ama"
        AMAController(config, ess, useCases)
    else
        throw(InvalidInput("Invalid real-time controller type: $controllerType"))
    end
    return controller
end

function __init__()
    @pyinclude(joinpath(@__DIR__, "amac.py"))
end

end