
struct RegulationPricePoint
    capacityPrice::Float64
    servicePrice::Float64
end

struct RegulationOperationPoint{TC<:Union{Real,JuMP.VariableRef},TM<:Union{Real,JuMP.VariableRef}}
    capacity::TC
    mileage::TM
end
struct Regulation <: UseCase
    price::FixedIntervalTimeSeries{Hour,RegulationPricePoint}
    perfermanceScore::Float64
end

function regulation_income(regOperation::TimeSeries{<:RegulationOperationPoint}, ucReg::Regulation)
    (ucReg.price ⋅ regOperation) * ucReg.perfermanceScore
end

import Base: *
*(pp::RegulationPricePoint, op::RegulationOperationPoint) = pp.capacityPrice * op.capacity + pp.servicePrice * op.capacity * op.mileage
*(op::RegulationOperationPoint, pp::RegulationPricePoint) = pp.capacityPrice * op.capacity + pp.servicePrice * op.capacity * op.mileage

function summarize_use_case(operation::OperationHistory, ucReg::Regulation)
    return Dict(:RegulationIncome => operation ⋅ ucReg.price)
end