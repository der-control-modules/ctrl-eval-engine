
struct Regulation <: UseCase
    price::EnergyPrice
end

function summarize_use_case(operation::OperationHistory, reg::Regulation)
    return Dict(:RegulationIncome => operation * reg.price)
end