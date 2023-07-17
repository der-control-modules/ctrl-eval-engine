using MesaEss: MesaController, VertexCurve, RampParams

struct ActivePowerSmoothingMode <: MesaMode
    smoothingGradient::Float64
    lowerSmoothingLimit::Float64
    upperSmoothingLimit::Float64
    smoothingFilterTime::Dates.Second
    rampParams::RampParams
end


function modecontrol(
    mode::ActivePowerSmoothingMode,
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
