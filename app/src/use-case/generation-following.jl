using CtrlEvalEngine

struct GenerationFollowing <: UseCase
    forecastPower::TimeSeries
    realtimePower::TimeSeries
end

"""
    GenerationFollowing(input)

Construct a `GenerationFollowing` object from `input` dictionary or array
"""
GenerationFollowing(input::Dict) = GenerationFollowing(
    FixedIntervalTimeSeries(
        DateTime(input["forecastPower"][1]["DateTime"]),
        DateTime(input["forecastPower"][2]["DateTime"]) - DateTime(input["forecastPower"][1]["DateTime"]),
        [float(row["Power"]) for row in input["forecastPower"]]
    ),
    FixedIntervalTimeSeries(
        DateTime(input["realtimePower"][1]["DateTime"]),
        DateTime(input["realtimePower"][2]["DateTime"]) - DateTime(input["realtimePower"][1]["DateTime"]),
        [float(row["value"]) for row in input["realtimePower"]]
    )
)

function calculate_metrics(operation::OperationHistory, ucLF::GenerationFollowing)
    [
        Dict(
            :sectionTitle => "Generation Following",
        ),
        Dict(
            :label => "RMSE",
            :value => 0
        ),
        Dict(
            :label => "Maximum Deviation",
            :value => 0
        )
    ]
end

function use_case_charts(operation::OperationHistory, ucLF::GenerationFollowing)
    [
        # TODO: this is an example to be replaced
        Dict(
            :title => "Generation Following Performance",
            :height => "400px",
            :xAxis => Dict(:title => "Time"),
            :yAxisLeft => Dict(:title => "Power (kW)"),
            :yAxisRight => Dict(:title => "Error (%)", :tickformat => ",.0%"),
            :data => [
                Dict(
                    :x => timestamps(ucLF.forecastPower),
                    :y => get_values(ucLF.forecastPower),
                    :type => "interval",
                    :name => "Forecast Generation Power"
                ),
                Dict(
                    :x => timestamps(ucLF.realtimePower),
                    :y => get_values(ucLF.realtimePower),
                    :type => "interval",
                    :name => "Real-time Generation Power"
                ),
                Dict(
                    :x => timestamps(ucLF.realtimePower),
                    :y => zeros(length(get_values(ucLF.realtimePower))), # TODO: to be replaced with actual errors
                    :type => "interval",
                    :name => "Relative Error",
                    :yAxis => "right"
                ),
            ]
        ),
    ]
end
