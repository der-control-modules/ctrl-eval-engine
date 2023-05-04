
struct EnergyArbitrage <: UseCase
    price::TimeSeries
end

"""
    EnergyArbitrage(input)

Construct an `EnergyArbitrage` object from `input` dictionary or array
"""
EnergyArbitrage(input::Dict) = EnergyArbitrage(
    VariableIntervalTimeSeries(
        push!(DateTime.(input["t"]), DateTime(input["t"][end]) + Hour(1)),
        Float64.(input["actualPriceData"])
    )
)

EnergyArbitrage(input::AbstractVector) = EnergyArbitrage(
    VariableIntervalTimeSeries(
        push!([DateTime(row["date"]) for row in input], DateTime(input[end]["date"]) + Hour(1)),
        [Float64(row["lmp"]) for row in input]
    )
)


"""
    summarize_use_case(operation, useCase)

Summarize the benefit and cost associated with `useCase` given `operation`
"""
function calculate_metrics(operation::OperationHistory, eaUseCase::EnergyArbitrage)
    return [
        Dict(
            :sectionTitle => "Energy Arbitrage",
        ),
        Dict(
            :label => "Net Income",
            :value => power(operation) ⋅ eaUseCase.price
        )
    ]
end

