using CtrlEvalEngine

# TODO: deprecated. Make sure this works without this.
# """
#
#     LoadPower
#
# `LoadPower` represents the load power `value` in kW over a period of time with corresponding timestamps `t`.
# `length(t)` should equal to `length(power) + 1`.
# """
# struct LoadPower
#     t::Vector{Dates.DateTime}
#     value::Vector{Float64} # unit: $/kWh
# end
#
# Base.iterate(lp::LoadPower, index=1) = index > length(lp.value) ? nothing : ((lp.value[index], lp.t[index], lp.t[index + 1]), index + 1)
# Base.length(lp::LoadPower) = length(lp.value)

struct LoadFollowing <: UseCase
    forecastLoadPower::TimeSeries
    realtimeLoadPower::TimeSeries
end

"""
    LoadFollowing(input)

Construct a `LoadFollowing` object from `input` dictionary or array
"""
LoadFollowing(input::Dict) = LoadFollowing(
    FixedIntervalTimeSeries(
        DateTime(input["forecastLoadPower"]["DateTime"][1]),
        DateTime(input["forecastLoadPower"]["DateTime"][2]) -
        DateTime(input["forecastLoadPower"]["DateTime"][1]),
        float.(input["forecastLoadPower"]["Power"]),
    ),
    FixedIntervalTimeSeries(
        DateTime(input["realTimeLoadPower"]["DateTime"][1]),
        DateTime(input["realTimeLoadPower"]["DateTime"][2]) -
        DateTime(input["realTimeLoadPower"]["DateTime"][1]),
        float.(input["realTimeLoadPower"]["Power"]),
    ),
)

LoadFollowing(input::Dict, tStart::DateTime, tEnd::DateTime) = LoadFollowing(
    extract(
        FixedIntervalTimeSeries(
            DateTime(input["forecastLoadProfile"]["DateTime"][1]),
            DateTime(input["forecastLoadProfile"]["DateTime"][2]) -
            DateTime(input["forecastLoadProfile"]["DateTime"][1]),
            float.(input["forecastLoadProfile"]["Power"]),
        ),
        tStart,
        tEnd,
    ),
    extract(
        FixedIntervalTimeSeries(
            DateTime(input["realTimeLoadProfile"]["DateTime"][1]),
            DateTime(input["realTimeLoadProfile"]["DateTime"][2]) -
            DateTime(input["realTimeLoadProfile"]["DateTime"][1]),
            float.(input["realTimeLoadProfile"]["Power"]),
        ),
        tStart,
        tEnd,
    ),
)

function calculate_metrics(
    sh::ScheduleHistory,
    operation::OperationHistory,
    ucLF::LoadFollowing,
)
    tsNetLoad = ucLF.realtimeLoadPower - power(operation)
    tsError = tsNetLoad - (ucLF.forecastLoadPower - power(sh))
    [
        Dict(:sectionTitle => "Load Following"),
        Dict(:label => "RMSE", :value => "$(round(sqrt(mean(tsError^2)), sigdigits=2)) kW"),
        Dict(
            :label => "Maximum Deviation",
            :value => "$(round(maximum(abs.(get_values(tsError))), sigdigits=2)) kW",
        ),
    ]
end

function use_case_charts(
    sh::ScheduleHistory,
    operation::OperationHistory,
    ucLF::LoadFollowing,
)
    tsScheduledNetLoad = ucLF.forecastLoadPower - power(sh)
    tsRtNetLoad = ucLF.realtimeLoadPower - power(operation)
    tsRelError = (tsRtNetLoad - ucLF.forecastLoadPower) / ucLF.forecastLoadPower
    [
        Dict(
            :title => "Load Following Performance",
            :height => "350px",
            :yAxisLeft => Dict(:title => "Power (kW)"),
            :data => [
                Dict(
                    :x => timestamps(ucLF.forecastLoadPower),
                    :y => get_values(ucLF.forecastLoadPower),
                    :type => "interval",
                    :name => "Forecast Load",
                    :line => Dict(:dash => :dash),
                ),
                Dict(
                    :x => timestamps(tsScheduledNetLoad),
                    :y => get_values(tsScheduledNetLoad),
                    :type => "interval",
                    :name => "Scheduled Net Load",
                    :line => Dict(:dash => :dash),
                ),
                Dict(
                    :x => timestamps(ucLF.realtimeLoadPower),
                    :y => get_values(ucLF.realtimeLoadPower),
                    :type => "interval",
                    :name => "Real-time Load",
                ),
                Dict(
                    :x => timestamps(tsRtNetLoad),
                    :y => get_values(tsRtNetLoad),
                    :type => "interval",
                    :name => "Real-time Net Load",
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
