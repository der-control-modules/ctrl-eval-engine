
struct EnergyArbitrage <: UseCase
    actualPrice::TimeSeries
    forecastPrice::Union{TimeSeries,Nothing}
end

EnergyArbitrage(actualPrice::TimeSeries) = EnergyArbitrage(actualPrice, nothing)

"""
    EnergyArbitrage(input)

Construct an `EnergyArbitrage` object from `input` dictionary or array
"""
EnergyArbitrage(input::Dict) = EnergyArbitrage(
    FixedIntervalTimeSeries(
        DateTime(input["actualEnergyPrice"]["Time"][1]),
        DateTime(input["actualEnergyPrice"]["Time"][2]) -
        DateTime(input["actualEnergyPrice"]["Time"][1]),
        float.(input["actualEnergyPrice"]["EnergyPrice_per_MWh"]) ./ 1000,
    ),
    if get(input, "forecastPrice", nothing) === nothing
        nothing
    else
        FixedIntervalTimeSeries(
            DateTime(input["forecastEnergyPrice"]["Time"][1]),
            DateTime(input["forecastEnergyPrice"]["Time"][2]) -
            DateTime(input["forecastEnergyPrice"]["Time"][1]),
            float.(input["forecastEnergyPrice"]["EnergyPrice_per_MWh"]) ./ 1000,
        )
    end,
)

EnergyArbitrage(input::Dict, tStart::DateTime, tEnd::DateTime) = EnergyArbitrage(
    extract(
        FixedIntervalTimeSeries(
            DateTime(input["actualEnergyPrice"]["Time"][1]),
            DateTime(input["actualEnergyPrice"]["Time"][2]) -
            DateTime(input["actualEnergyPrice"]["Time"][1]),
            float.(input["actualEnergyPrice"]["EnergyPrice_per_MWh"]) ./ 1000,
        ),
        tStart,
        tEnd,
    ),
    if get(input, "forecastPrice", nothing) === nothing
        nothing
    else
        extract(
            FixedIntervalTimeSeries(
                DateTime(input["forecastEnergyPrice"]["Time"][1]),
                DateTime(input["forecastEnergyPrice"]["Time"][2]) -
                DateTime(input["forecastEnergyPrice"]["Time"][1]),
                float.(input["forecastEnergyPrice"]["EnergyPrice_per_MWh"]) ./ 1000,
            ),
            tStart,
            tEnd,
        )
    end,
)

forecast_price(ucEA::EnergyArbitrage) =
    isnothing(ucEA.forecastPrice) ? ucEA.actualPrice : ucEA.forecastPrice

calculate_net_benefit(progress::Progress, ucEA::EnergyArbitrage) =
    power(progress.operation) ⋅ ucEA.actualPrice

"""
    calculate_metrics(operation, useCase)

Summarize the benefit and cost associated with `useCase` given `operation`
"""
function calculate_metrics(
    ::ScheduleHistory,
    operation::OperationHistory,
    ucEA::EnergyArbitrage,
)
    return [
        Dict(:sectionTitle => "Energy Arbitrage"),
        Dict(
            :label => "Net Income",
            :value => power(operation) ⋅ ucEA.actualPrice,
            :type => "currency",
        ),
    ]
end

use_case_charts(::ScheduleHistory, op::OperationHistory, ucEA::EnergyArbitrage) = begin
    @debug "Generating time series charts for Energy Arbitrage"

    cumIncome = cum_integrate(power(op) * ucEA.actualPrice)

    priceTraces = if isnothing(ucEA.forecastPrice)
        [
            Dict(
                :x => timestamps(ucEA.actualPrice),
                :y => get_values(ucEA.actualPrice),
                :type => "interval",
                :name => "Energy Price",
                :yAxis => "right",
            ),
        ]
    else
        [
            Dict(
                :x => timestamps(ucEA.forecastPrice),
                :y => get_values(ucEA.forecastPrice),
                :type => "interval",
                :name => "Forecast Energy Price",
                :yAxis => "right",
            ),
            Dict(
                :x => timestamps(ucEA.actualPrice),
                :y => get_values(ucEA.actualPrice),
                :type => "interval",
                :name => "Actual Energy Price",
                :yAxis => "right",
            ),
        ]
    end

    [
        Dict(
            :title => "Energy Arbitrage",
            :xAxis => Dict(:title => "Time"),
            :yAxisLeft => Dict(:title => "Power (kW)"),
            :yAxisRight => Dict(:title => raw"Price ($/kWh)"),
            :data => [
                Dict(
                    :x => op.t,
                    :y => op.powerKw,
                    :type => "interval",
                    :name => "Actual Power",
                ),
                priceTraces...,
            ],
        ),
        Dict(
            :xAxis => Dict(:title => "Time"),
            :yAxisLeft => Dict(:title => raw"Cumulative Net Income ($)"),
            :data => [
                Dict(
                    :x => timestamps(cumIncome),
                    :y => pushfirst!(get_values(cumIncome), 0),
                    :type => "instance",
                ),
            ],
        ),
    ]
end