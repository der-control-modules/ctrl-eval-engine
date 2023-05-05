
export VariabilityMitigation

struct VariabilityMitigation <: UseCase
    pvGenProfile::FixedIntervalTimeSeries{<:TimePeriod,Float64}
    ratedPower::Float64
end

"""
    VariabilityMitigation(input)

Construct an `VariabilityMitigation` object from `input` dictionary or array
"""
VariabilityMitigation(inputDict::Dict) = VariabilityMitigation(
    FixedIntervalTimeSeries(
        DateTime(inputDict["pvGenProfile"][1]["DateTime"]),
        DateTime(inputDict["pvGenProfile"][2]["DateTime"]) - DateTime(inputDict[1]["DateTime"]),
        [Float64(row["Power"]) for row in inputDict["pvGenProfile"]]
    ),
    inputDict["ratedPowerKw"]
)