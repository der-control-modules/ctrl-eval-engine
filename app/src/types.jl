
using Dates
using LinearAlgebra

struct SimSetting
    simStart::Dates.DateTime
    simEnd::Dates.DateTime
end

abstract type TimeSeries{V} end

"""
    VariableIntervalTimeSeries

`VariableIntervalTimeSeries` represents a time series defined with variable time intervals.
The value of time series is defined as `value[i]` during the `i`th time period (from `t[i]` to `t[i + 1]`),
where `1 ≤ i ≤ length(value)` and `length(t) == length(value) + 1`.
"""
struct VariableIntervalTimeSeries{V} <: TimeSeries{V}
    t::Vector{Dates.DateTime}
    value::Vector{V}
    VariableIntervalTimeSeries(t, v) =
        length(t) == length(v) + 1 ? new{eltype(v)}(t, v) : error("Incompatible lengths")
end

start_time(ts::VariableIntervalTimeSeries) = ts.t[1]

end_time(ts::VariableIntervalTimeSeries) = ts.t[end]

timestamps(ts::VariableIntervalTimeSeries) = ts.t

values(ts::TimeSeries) = ts.value

sample(ts::TimeSeries, tArray::AbstractArray{DateTime}) =
    map(t -> get_period(ts, t)[1], tArray)

function extract(ts::VariableIntervalTimeSeries, tStart::DateTime, tEnd::DateTime)
    t1 = max(tStart, start_time(ts))
    t2 = min(tEnd, end_time(ts))
    if t1 < ts.t[end] && t2 ≥ ts.t[1]
        # some overlap time period
        idx1 = findfirst(ts.t .> t1) - 1
        idx2 = findfirst(ts.t .> t2) - 1
        VariableIntervalTimeSeries(
            [tStart, ts.t[idx1+1:idx2]..., tEnd],
            ts.value[idx1:idx2],
        )
    else
        VariableIntervalTimeSeries([tStart], [])
    end
end

"""
    get_period(ts, t)

Return the value of `ts` at `t` and the defined time period that encloses `t`.
"""
get_period(ts::VariableIntervalTimeSeries, t::DateTime) = begin
    if t ≥ ts.t[1] && t < ts.t[end]
        index = findfirst(ts.t .> t) - 1
        (ts.value[index], ts.t[index], ts.t[index+1])
    else
        (nothing, nothing, nothing)
    end
end

struct FixedIntervalTimeSeries{R<:Dates.Period,V} <: TimeSeries{V}
    tStart::Dates.DateTime
    resolution::R
    value::Vector{V}
end

start_time(ts::FixedIntervalTimeSeries) = ts.tStart

end_time(ts::FixedIntervalTimeSeries) = ts.tStart + ts.resolution * length(ts.value)

timestamps(ts::FixedIntervalTimeSeries) =
    range(ts.tStart; step = ts.resolution, length = length(ts.value) + 1)

function extract(ts::FixedIntervalTimeSeries, tStart::DateTime, tEnd::DateTime)
    t1 = max(tStart, start_time(ts))
    t2 = min(tEnd, end_time(ts))
    if t1 < end_time(ts) && t2 ≥ start_time(ts)
        # some overlap time period
        idx1 = div(t1 - ts.tStart, ts.resolution) + 1
        idx2 = div(t2 - ts.tStart, ts.resolution) + 1
        if Dates.value((t1 - ts.tStart) % ts.resolution) == 0 &&
           Dates.value((t2 - ts.tStart) % ts.resolution) == 0
            FixedIntervalTimeSeries(tStart, ts.resolution, ts.value[idx1:idx2])
        else
            VariableIntervalTimeSeries(
                [tStart, (ts.tStart .+ (idx1:idx2-1) .* ts.resolution)..., tEnd],
                ts.value[idx1:idx2],
            )
        end
    else
        VariableIntervalTimeSeries([tStart], [])
    end
end

get_period(ts::FixedIntervalTimeSeries, t::DateTime) = begin
    index = floor(Int64, /(promote(t - ts.tStart, ts.resolution)...)) + 1
    if index ≥ 1 && index ≤ length(ts.value)
        (
            ts.value[index],
            ts.tStart + ts.resolution * (index - 1),
            ts.tStart + ts.resolution * index,
        )
    else
        (nothing, nothing, nothing)
    end
end

function dot_multiply_time_series(ts1::TimeSeries, ts2::TimeSeries)
    @assert start_time(ts1) < end_time(ts2) && start_time(ts2) < end_time(ts1) "The time ranges must overlap"
    tStart = max(start_time(ts1), start_time(ts2))
    tEnd = min(end_time(ts1), end_time(ts2))
    tPeriodStart = tStart
    v1, _, tPeriodEnd1 = get_period(ts1, tPeriodStart)
    v2, _, tPeriodEnd2 = get_period(ts2, tPeriodStart)
    tPeriodEnd = min(tPeriodEnd1, tPeriodEnd2)
    netIncome = v1 * v2 * /(promote(tPeriodEnd - tPeriodStart, Hour(1))...)

    while tPeriodEnd < tEnd
        tPeriodStart = tPeriodEnd
        if tPeriodEnd1 ≤ tPeriodEnd2
            # this means tPeriodEnd == tPeriodEnd1, move ts1 forward by one time period
            v1, _, tPeriodEnd1 = get_period(ts1, tPeriodStart)
        else
            # this means tPeriodEnd == tPeriodEnd2, move ts2 forward by one time period
            v2, _, tPeriodEnd2 = get_period(ts2, tPeriodStart)
        end
        tPeriodEnd = min(tPeriodEnd1, tPeriodEnd2)
        netIncome += v1 * v2 * /(promote(tPeriodEnd - tPeriodStart, Hour(1))...)
    end
    return netIncome
end

LinearAlgebra.dot(ts1::TimeSeries, ts2::TimeSeries) = dot_multiply_time_series(ts1, ts2)

"""
    mean(ts, t1=start_time(ts), t2=end_time(ts))

Calculate the average value of `ts` during the time period from `t1` to `t2`.
"""
mean(ts::TimeSeries, t1::DateTime, t2::DateTime) =
    VariableIntervalTimeSeries([t1, t2], [1]) ⋅ ts / /(promote(t2 - t1, Hour(1))...)

mean(ts::TimeSeries) = mean(ts, start_time(ts), end_time(ts))

"""
    mean(ts::TimeSeries, t::AbstractVector{DateTime})

Return a new time series with the average values of `ts` during the time periods defined in `t`.
"""
function mean(ts::TimeSeries, t::AbstractVector{DateTime})
    values = [mean(ts, t[idx], t[idx+1]) for idx = 1:length(t)-1]
    VariableIntervalTimeSeries(t, values)
end

struct ScheduleHistory
    t::Vector{Dates.DateTime}
    powerKw::Vector{Float64}
end

"""
    OperationHistory

`OperationHistory` represents the operation history of an ESS over a period of time with corresponding timestamps `t`.
Both `length(t)` and `length(SOC)` should equal to `length(powerKw) + 1`.
"""
struct OperationHistory
    t::Vector{Dates.DateTime}
    powerKw::Vector{Float64}
    SOC::Vector{Float64}
    SOH::Vector{Float64}
end

start_time(op::OperationHistory) = op.t[1]

end_time(op::OperationHistory) = op.t[end]

power(op::OperationHistory) = VariableIntervalTimeSeries(op.t, op.powerKw)

discharged_energy(op::OperationHistory) = begin
    dischargePeriods = op.powerKw .> 0
    durationHours = (op.t[2:end] .- op.t[1:end-1]) ./ Hour(1)
    sum(op.powerKw[dischargePeriods] .* durationHours[dischargePeriods])
end

charged_energy(op::OperationHistory) = begin
    chargePeriods = op.powerKw .< 0
    durationHours = (op.t[2:end] .- op.t[1:end-1]) ./ Hour(1)
    -sum(op.powerKw[chargePeriods] .* durationHours[chargePeriods])
end

Base.iterate(op::OperationHistory, index=1) =
    index > length(op.powerKw) || index + 1 > length(op.t) ?
    nothing :
    (
        (
            op.t[index],
            op.t[index+1],
            op.powerKw[index]
        ),
        index + 1
    )

Base.eltype(::Type{OperationHistory}) = Tuple{DateTime,DateTime,Float64}
Base.length(op::OperationHistory) = min(length(op.powerKw), length(op.t) - 1)

mutable struct Progress
    progressPct::Float64
    schedule::ScheduleHistory
    operation::OperationHistory
end

mutable struct InvalidInput <: Exception
    msg::String
end

abstract type BatteryInput end

struct LiIonBatteryInput <: BatteryInput
    powerCapacityKw::Float64
    energyCapacityKwh::Float64
    roundtripEfficiency::Float64
    cycleLife::Float64
end
