
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

mutable struct Progress
    progressPct::Float64
    schedule::ScheduleHistory
    operation::OperationHistory
end


mutable struct InvalidInput <: Exception
    msg::String
end