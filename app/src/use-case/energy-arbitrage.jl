
struct EnergyArbitrage <: UseCase
    price::TimeSeries
end

"""
    EnergyArbitrage(input)

Construct an `EnergyArbitrage` object from `input` dictionary or array
"""
EnergyArbitrage(input::Dict) = EnergyArbitrage(
    TimeSeriesPrice(
        DateTime.(input["t"]),
        Float64.(input["actualPriceData"])
    )
)

EnergyArbitrage(input::AbstractVector) = EnergyArbitrage(
    TimeSeriesPrice(
        [DateTime(row["date"]) for row in input],
        [Float64(row["lmp"]) for row in input]
    )
)


"""
    summarize_use_case(operation, useCase)

Summarize the benefit and cost associated with `useCase` given `operation`
"""
function summarize_use_case(operation::OperationHistory, eaUseCase::EnergyArbitrage)
    return Dict(:netArbitrageIncome => power(operation) * eaUseCase.price)
end

