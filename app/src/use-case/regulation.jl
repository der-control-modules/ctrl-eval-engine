
struct RegulationPricePoint
    capacityPrice::Float64
    servicePrice::Float64
end

Base.:zero(::RegulationPricePoint) = RegulationPricePoint(0, 0)
Base.:zero(::Type{RegulationPricePoint}) = RegulationPricePoint(0, 0)

struct RegulationOperationPoint{
    TC<:Union{Real,JuMP.VariableRef},
    TM<:Union{Real,JuMP.VariableRef},
}
    capacity::TC
    mileage::TM
end

Base.:zero(::RegulationOperationPoint) = RegulationOperationPoint(0, 0)
Base.:zero(::Type{RegulationOperationPoint}) = RegulationOperationPoint(0, 0)

struct Regulation <: UseCase
    AGCSignalPercentage::FixedIntervalTimeSeries{<:Dates.TimePeriod, Float64}
    price::FixedIntervalTimeSeries{Hour,RegulationPricePoint}
    performanceScore::Float64
end

function regulation_income(
    regOperation::TimeSeries{<:RegulationOperationPoint},
    ucReg::Regulation,
)
    (ucReg.price ⋅ regOperation) * ucReg.performanceScore
end

import Base: *
*(pp::RegulationPricePoint, op::RegulationOperationPoint) =
    pp.capacityPrice * op.capacity + pp.servicePrice * op.capacity * op.mileage
*(op::RegulationOperationPoint, pp::RegulationPricePoint) =
    pp.capacityPrice * op.capacity + pp.servicePrice * op.capacity * op.mileage

function calculate_metrics(operation::OperationHistory, ucReg::Regulation)
    return [
        Dict(:sectionTitle => "Frequency Regulation"),
        Dict(:label => "Revenue (ex.)", :value => "\$4363.35"),
        Dict(:label => "AGC Signal Following RMSE (ex.)", :value => 1.34e-3),
    ]
end