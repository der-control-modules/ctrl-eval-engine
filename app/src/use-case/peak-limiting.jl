using CtrlEvalEngine

struct PeakLimiting <: UseCase
    peakThreshold::Float64
    realtimePower::TimeSeries
end

"""
    PeakLimiting(input)

Construct a `PeakLimiting` object from `input` dictionary or array
"""
PeakLimiting(input::Dict) = PeakLimiting(
    input["peakThreshold"],
    FixedIntervalTimeSeries(
        DateTime(input["realtimePower"][1]["DateTime"]),
        DateTime(input["realtimePower"][2]["DateTime"]) -
        DateTime(input["realtimePower"][1]["DateTime"]),
        [float(row["value"]) for row in input["realtimePower"]],
    ),
)

function calculate_metrics(
    ::ScheduleHistory,
    operation::OperationHistory,
    ucLF::PeakLimiting,
)
    [
        Dict(:sectionTitle => "Peak Limiting"),
        Dict(:label => "RMSE", :value => 0),
        Dict(:label => "Maximum Deviation", :value => 0),
    ]
end

function use_case_charts(::ScheduleHistory, operation::OperationHistory, ucLF::PeakLimiting)
    [
        # TODO: this is an example to be replaced
        Dict(
            :title => "Peak Limiting Performance",
            :height => "400px",
            :xAxis => Dict(:title => "Time"),
            :yAxisLeft => Dict(:title => "Power (kW)"),
            :yAxisRight => Dict(:title => "Error (%)", :tickformat => ",.0%"),
            :data => [
                Dict(
                    :x => timestamps(ucLF.forecastPower),
                    :y => get_values(ucLF.forecastPower),
                    :type => "interval",
                    :name => "Forecast  Power",
                ),
                Dict(
                    :x => timestamps(ucLF.realtimePower),
                    :y => get_values(ucLF.realtimePower),
                    :type => "interval",
                    :name => "Real-time  Power",
                ),
                Dict(
                    :x => timestamps(ucLF.realtimePower),
                    :y => zeros(length(get_values(ucLF.realtimePower))), # TODO: to be replaced with actual errors
                    :type => "interval",
                    :name => "Relative Error",
                    :yAxis => "right",
                ),
            ],
        ),
    ]
end
