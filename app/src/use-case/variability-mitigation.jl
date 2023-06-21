
struct VariabilityMitigation <: UseCase
    pvGenProfile::FixedIntervalTimeSeries{<:TimePeriod,Float64}
    ratedPowerKw::Float64
end

"""
    VariabilityMitigation(input)

Construct an `VariabilityMitigation` object from `input` dictionary or array
"""
VariabilityMitigation(config::Dict) = VariabilityMitigation(
    FixedIntervalTimeSeries(
        DateTime(config["pvGenProfile"][1]["DateTime"]),
        DateTime(config["pvGenProfile"][2]["DateTime"]) - DateTime(config["pvGenProfile"][1]["DateTime"]),
        [Float64(row["Power"]) for row in config["pvGenProfile"]]
    ),
    config["ratedPowerKw"]
)