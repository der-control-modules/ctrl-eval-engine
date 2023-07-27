
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
        DateTime(config["pvGenProfile"][2]["DateTime"]) -
        DateTime(config["pvGenProfile"][1]["DateTime"]),
        [Float64(row["Power"]) for row in config["pvGenProfile"]],
    ),
    config["ratedPowerKw"],
)

VariabilityMitigation(config::Dict, tStart::DateTime, tEnd::DateTime) =
    VariabilityMitigation(
        extract(
            FixedIntervalTimeSeries(
                DateTime(config["pvGenProfile"][1]["DateTime"]),
                DateTime(config["pvGenProfile"][2]["DateTime"]) -
                DateTime(config["pvGenProfile"][1]["DateTime"]),
                [Float64(row["Power"]) for row in config["pvGenProfile"]],
            ),
            tStart,
            tEnd,
        ),
        config["ratedPowerKw"],
    )

moving_std(ts::TimeSeries, windowLength::Dates.TimePeriod, samplingRate::Dates.TimePeriod) =
    begin
        tStart = start_time(ts) + windowLength
        # if tStart > end_time(ts)
        #     return FixedIntervalTimeSeries(tStart, samplingRate, [])
        # end

        v = [std(ts, t - windowLength, t) for t = tStart:samplingRate:end_time(ts)]
        return FixedIntervalTimeSeries(tStart, samplingRate, v)
    end

calculate_metrics(op::OperationHistory, ucVM::VariabilityMitigation) = begin
    essPower = power(op)
    netPowerSmooth = essPower + ucVM.pvGenProfile
    originalMaxVariability = maximum(moving_std(ucVM.pvGenProfile, Minute(10), ucVM.pvGenProfile.resolution))
    smoothedMaxVariability = maximum(moving_std(netPowerSmooth, Minute(10), ucVM.pvGenProfile.resolution))
    mitigatedVariabilityPct = (originalMaxVariability - smoothedMaxVariability) / originalMaxVariability * 100

    [
        Dict(:sectionTitle => "Variability Mitigation"),
        Dict(:label => "Mitigated Variability", :value => "$(mitigatedVariabilityPct)%"),
        Dict(:label => "SOC Deviation", :value => "0%"),
    ]
end

use_case_charts(op::OperationHistory, ucVM::VariabilityMitigation) = []