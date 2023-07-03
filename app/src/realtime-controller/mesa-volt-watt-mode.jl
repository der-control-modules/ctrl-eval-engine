using MesaEss: MesaController, VertexCurve, RampParams

struct VoltWattModeController <: MesaController
    referenceVoltageOffset::Float64
    voltWattCurve::VertexCurve
    gradient::Float64
    filterTime::Dates.Second
    lowerDeadband::Float64
    upperDeadband::Float64
end

function control(
    ess::EnergyStorageSystem,
    controller::VoltWattModeController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries
)

end