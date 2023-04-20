
using Dates

struct SimSetting
    simStart::Dates.DateTime
    simEnd::Dates.DateTime
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
end

start_time(op::OperationHistory) = op.t[1]
end_time(op::OperationHistory) = op.t[end]

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