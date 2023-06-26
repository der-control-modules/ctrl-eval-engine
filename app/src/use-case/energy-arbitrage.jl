
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
        Float64.(input["actualPriceData"]),
    ),
)

EnergyArbitrage(input::AbstractVector{<:Dict}) = EnergyArbitrage(
    VariableIntervalTimeSeries(
        push!(
            [DateTime(row["date"]) for row in input],
            DateTime(input[end]["date"]) + Hour(1),
        ),
        [Float64(row["lmp"]) for row in input],
    ),
)

EnergyArbitrage(input::AbstractVector{<:Dict}, tStart::DateTime, tEnd::DateTime) =
    EnergyArbitrage(
        truncate(
            VariableIntervalTimeSeries(
                push!(
                    [DateTime(row["date"]) for row in input],
                    DateTime(input[end]["date"]) + Hour(1),
                ),
                [Float64(row["lmp"]) for row in input],
            ),
            tStart,
            tEnd,
        ),
    )

calculate_net_benefit(progress::Progress, ucEA::EnergyArbitrage) =
    power(progress.operation) ⋅ ucEA.price

"""
    calculate_metrics(operation, useCase)

Summarize the benefit and cost associated with `useCase` given `operation`
"""
function calculate_metrics(operation::OperationHistory, ucEA::EnergyArbitrage)
    return [
        Dict(:sectionTitle => "Energy Arbitrage"),
        Dict(:label => "Net Income", :value => power(operation) ⋅ ucEA.price),
    ]
end

use_case_charts(op::OperationHistory, ucEA::EnergyArbitrage) = [
    Dict(
        :title => "Energy Arbitrage",
        :xAxis => Dict(:title => "Time"),
        :yAxisLeft => Dict(:title => "Power (kW)"),
        :yAxisRight => Dict(:title => "Price ($/kWh)"),
        :data => [
            Dict(
                :x => op.t,
                :y => op.powerKw,
                :type => "interval",
                :name => "Actual Power",
            ),
            Dict(
                :x => timestamps(ucEA.price),
                :y => values(ucEA.price),
                :type => "interval",
                :name => "Energy Price",
                :yAxis => "right",
            ),
        ],
    ),
    Dict(
        :xAxis => Dict(:title => "Time"),
        :yAxisLeft => Dict(:title => "Cumulative Net Income ($)"),
        :data => [
            Dict(
                :x => timestamps(ucEA.price),
                :y =>
                    values(mean(power(op), timestamps(ucEA.price))) .* values(ucEA.price),
                :type => "interval",
            ),
        ],
    ),
]