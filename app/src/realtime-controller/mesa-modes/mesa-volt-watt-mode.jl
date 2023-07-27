using CtrlEvalEngine.EnergyStorageRTControl: MesaController, VertexCurve, RampParams

struct VoltWattMode <: MesaMode
    params::MesaModeParams
    referenceVoltageOffset::Float64
    voltWattCurve::VertexCurve
    gradient::Float64
    filterTime::Dates.Second
    lowerDeadband::Float64
    upperDeadband::Float64
end

function modecontrol(
    mode::VoltWattMode,
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