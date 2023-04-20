
struct Regulation <: UseCase
    price::Vector{Float64}
    resolution::Dates.TimePeriod
    tStart::Dates.DateTime
    perfermanceScore::Float64
end

function summarize_use_case(operation::OperationHistory, ucReg::Regulation)
    return Dict(:RegulationIncome => operation * ucReg.price)
end