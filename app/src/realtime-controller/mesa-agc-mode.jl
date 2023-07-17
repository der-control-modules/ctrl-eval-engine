using MesaEss: MesaController, VertexCurve, RampParams

struct AGCMode <: MesaMode
    rampOrTimeConstant::Bool
    rampParams::RampParams
    minimumUsableSOC::Float64
    maximumUsableSOC::Float64
end

function modecontrol(
    mode::AGCMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries
)
    # TODO: Stuff
    controller.wip = [
        i # TODO: Actual stuff
        for i in t:mockController.resolution:tEnd
    ]
end