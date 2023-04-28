
using PyCall

struct AMAController <: RTController
    resolution::Dates.Period
    pyAmac
end

pushfirst!(pyimport("sys")."path", @__DIR__)
pyAmacModule = pyimport("amac")

function AMAController(controlConfig::Dict)
    amac = pyAmacModule.AMACOperation()
    AMAController(Second(1), amac)
end

function control(ess, amac::AMAController, schedulePeriod::SchedulePeriod, useCases, t, spProgress)

end