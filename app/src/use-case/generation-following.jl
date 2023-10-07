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
        DateTime(input["forecastGenProfile"]["DateTime"][1]),
        DateTime(input["forecastGenProfile"]["DateTime"][2]) -
        DateTime(input["forecastGenProfile"]["DateTime"][1]),
        float.(input["forecastGenProfile"]["Power"]),
    ),
    FixedIntervalTimeSeries(
        DateTime(input["realTimeGenProfile"]["DateTime"][1]),
        DateTime(input["realTimeGenProfile"]["DateTime"][2]) -
        DateTime(input["realTimeGenProfile"]["DateTime"][1]),
        float.(input["realTimeGenProfile"]["Power"]),
    ),
)

GenerationFollowing(input::Dict, tStart::DateTime, tEnd::DateTime) = GenerationFollowing(
    extract(
        FixedIntervalTimeSeries(
            DateTime(input["forecastGenProfile"]["DateTime"][1]),
            DateTime(input["forecastGenProfile"]["DateTime"][2]) -
            DateTime(input["forecastGenProfile"]["DateTime"][1]),
            float.(input["forecastGenProfile"]["Power"]),
        ),
        tStart,
        tEnd,
    ),
    extract(
        FixedIntervalTimeSeries(
            DateTime(input["realTimeGenProfile"]["DateTime"][1]),
            DateTime(input["realTimeGenProfile"]["DateTime"][2]) -
            DateTime(input["realTimeGenProfile"]["DateTime"][1]),
            float.(input["realTimeGenProfile"]["Power"]),
        ),
        tStart,
        tEnd,
    ),
)

function calculate_metrics(
    ::ScheduleHistory,
    operation::OperationHistory,
    ucLF::GenerationFollowing,
)
    [
        Dict(:sectionTitle => "Generation Following"),
        Dict(:label => "RMSE", :value => 0),
        Dict(:label => "Maximum Deviation", :value => 0),
    ]
end

function use_case_charts(
    sh::ScheduleHistory,
    operation::OperationHistory,
    ucGF::GenerationFollowing,
)
    tsScheduledNetGen = ucGF.forecastPower + power(sh)
    tsRtNetGen = ucGF.realtimePower + power(operation)
    tsRelError = (tsRtNetGen - ucGF.forecastPower) / ucGF.forecastPower
    [
        Dict(
            :title => "Generation Following Performance",
            :height => "350px",
            :yAxisLeft => Dict(:title => "Power (kW)"),
            :data => [
                Dict(
                    :x => timestamps(ucGF.forecastPower),
                    :y => get_values(ucGF.forecastPower),
                    :type => "interval",
                    :name => "Forecast/Scheduled Generation",
                    :line => Dict(:dash => :dash),
                ),
                Dict(
                    :x => timestamps(tsScheduledNetGen),
                    :y => get_values(tsScheduledNetGen),
                    :type => "interval",
                    :name => "Forecast/Scheduled Net Generation",
                    :line => Dict(:dash => :dash),
                ),
                Dict(
                    :x => timestamps(ucGF.realtimePower),
                    :y => get_values(ucGF.realtimePower),
                    :type => "interval",
                    :name => "Real-time Generation",
                ),
                Dict(
                    :x => timestamps(tsRtNetGen),
                    :y => get_values(tsRtNetGen),
                    :type => "interval",
                    :name => "Real-time Net Generation",
                ),
            ],
        ),
        Dict(
            :height => "300px",
            :xAxis => Dict(:title => "Time"),
            :yAxisLeft => Dict(:title => "Error (%)", :tickformat => ",.0%"),
            :data => [
                Dict(
                    :x => timestamps(tsRelError),
                    :y => get_values(tsRelError),
                    :type => "interval",
                    :name => "Relative Error",
                ),
            ],
        ),
    ]
end
