using MesaEss: MesaController, VertexCurve, RampParams

struct AGCModeControler <: MesaController
    rampOrTimeConstant::Bool
    rampParams::RampParams
    minimumUsableSOC::Float64
    maximumUsableSOC::Float64
end

function control(
    ess::EnergyStorageSystem,
    controller::AGCModeControler,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries
)

end