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
        DateTime(input["forecastLoadPower"][1]["DateTime"]),
        DateTime(input["forecastLoadPower"][2]["DateTime"]) - DateTime(input["forecastLoadPower"][1]["DateTime"]),
        [float(row["Power"]) for row in input["forecastLoadPower"]]
    ),
    FixedIntervalTimeSeries(
        DateTime(input["realtimeLoadPower"][1]["DateTime"]),
        DateTime(input["realtimeLoadPower"][2]["DateTime"]) - DateTime(input["realtimeLoadPower"][1]["DateTime"]),
        [float(row["value"]) for row in input["realtimeLoadPower"]]
    )
)
