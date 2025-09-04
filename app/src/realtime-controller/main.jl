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

export get_rt_controller,
    control,
    PIDController,
    AMAController,
    RuleBasedController,
    MesaController,
    MesaMode,
    Vertex,
    VertexCurve,
    RampParams,
    previous_WIP

abstract type RTController end

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

include("passthrough.jl")
include("pid.jl")
include("amac.jl")
include("rule-based.jl")
include("mesa.jl")

"""
    get_rt_controller(inputDict::Dict, ess::EnergyStorageSystem, useCases::AbstractArray{<:UseCase})

Create a realtime controller of appropriate type from the input dictionary
"""
function get_rt_controller(
    config::Dict,
    ess::EnergyStorageSystem,
    useCases::AbstractArray{<:UseCase},
)
    try
        controllerType = config["type"]
        res = Millisecond(
            round(
                Int,
                convert(Millisecond, Second(1)).value * get(config, "resolutionSec", 60),
            ),
        )
        controller = if controllerType == "passthrough"
            PassThroughController()
        elseif controllerType == "pid"
            PIDController(res, float(config["Kp"]), float(config["Ti"]), float(config["Td"]))
        elseif controllerType == "ama"
            AMAController(config, ess, useCases)
        elseif controllerType == "realTimeRule"
            RuleBasedController(config)
        else
            throw(InvalidInput("Invalid real-time controller type: $controllerType"))
        end
        return controller
    catch e
        if e isa KeyError
            throw(InvalidInput("Missing key in real-time controller config - \"$(e.key)\""))
        else
            rethrow()
        end
    end
end

function __init__()
    @pyinclude(joinpath(@__DIR__, "amac.py"))
end

end