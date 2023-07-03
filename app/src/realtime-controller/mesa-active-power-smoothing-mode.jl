using MesaEss: MesaController, VertexCurve, RampParams

struct ActivePowerSmoothingModeController <: MesaController
    smoothingGradient::Float64
    lowerSmoothingLimit::Float64
    upperSmoothingLimit::Float64
    smoothingFilterTime::Dates.Second
    rampParams::RampParams
end


function control(
    ess::EnergyStorageSystem,
    controller::ActivePowerSmoothingModeController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries
)

end