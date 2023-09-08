
struct EnergyArbitrage <: UseCase
    price::TimeSeries
end

"""
    EnergyArbitrage(input)

Construct an `EnergyArbitrage` object from `input` dictionary or array
"""
EnergyArbitrage(input::Dict) =
    EnergyArbitrage(
        FixedIntervalTimeSeries(
            DateTime(input["actualEnergyPrice"]["Time"][1]),
            DateTime(input["actualEnergyPrice"]["Time"][2]) -
            DateTime(input["actualEnergyPrice"]["Time"][1]),
            float.(input["actualEnergyPrice"]["EnergyPrice_per_MWh"]) ./ 1000,
        ),
    )

EnergyArbitrage(input::Dict, tStart::DateTime, tEnd::DateTime) =
    EnergyArbitrage(
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
    )

calculate_net_benefit(progress::Progress, ucEA::EnergyArbitrage) =
    power(progress.operation) ⋅ ucEA.price

"""
    calculate_metrics(operation, useCase)

Summarize the benefit and cost associated with `useCase` given `operation`
"""
function calculate_metrics(::ScheduleHistory, operation::OperationHistory, ucEA::EnergyArbitrage)
    return [
        Dict(:sectionTitle => "Energy Arbitrage"),
        Dict(
            :label => "Net Income",
            :value => power(operation) ⋅ ucEA.price,
            :type => "currency",
        ),
    ]
end

use_case_charts(::ScheduleHistory, op::OperationHistory, ucEA::EnergyArbitrage) = begin
    @debug "Generating time series charts for Energy Arbitrage"

    cumIncome = cum_integrate(power(op) * ucEA.price)

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
                Dict(
                    :x => timestamps(ucEA.price),
                    :y => get_values(ucEA.price),
                    :type => "interval",
                    :name => "Energy Price",
                    :yAxis => "right",
                ),
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