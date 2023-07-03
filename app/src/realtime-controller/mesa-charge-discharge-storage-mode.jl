using MesaEss: MesaController, VertexCurve, RampParams

struct ChargeDischargeStorageModeController <: MesaController
    rampOrTimeConstant::Bool
    rampParams::RampParams
    minimumReservePercent::Float64
    maximumReservePercent::Float64
    active_power_target::Float64
end


function control(
    ess::EnergyStorageSystem,
    controller::ChargeDischargeStorageModeController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries
)

end