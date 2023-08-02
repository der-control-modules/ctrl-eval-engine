using CtrlEvalEngine.EnergyStorageRTControl: MesaController, VertexCurve, RampParams

struct AGCMode <: MesaMode
    params::MesaModeParams
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
    spProgress::VariableIntervalTimeSeries,
    currentIterationPower::Float64
)
    # TODO: Stuff
end