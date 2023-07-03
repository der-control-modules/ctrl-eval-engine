using MesaEss: MesaController, VertexCurve, RampParams

struct ActiveResponseModeController <: MesaController
    activationThreshold::Float64
    outputRatio::Float64
    maximumRampUp::Float64
    maximumRampDown::Float64
end


function control(
    ess::EnergyStorageSystem,
    controller::ActiveResponseModeController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries
)

end