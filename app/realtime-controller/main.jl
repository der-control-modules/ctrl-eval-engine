"""
    EnergyStorageRTControl

The `EnergyStorageRTControl` provides type and functions related to the realtime control of energy storage systems.
"""
module EnergyStorageRTControl

using Dates

export get_rt_controller, control

abstract type RTController end

struct ControlOperations
    powerKw::Vector{Float64}
    resolution::Dates.TimePeriod
end

Base.iterate(ops::ControlOperations, index=1) = index > length(ops.powerKw) ? nothing : ((ops.powerKw[index], ops.resolution), index + 1)
Base.eltype(::Type{ControlOperations}) = Tuple{Float64, Dates.TimePeriod}
Base.length(ops::ControlOperations) = length(ops.powerKw)

include("mock-rt-controller.jl")

"""
    get_rt_controller(inputDict::Dict)

Create a realtime controller of appropriate type from the input dictionary
"""
function get_rt_controller(inputDict::Dict)
    return MockController(Minute(15))
end

end