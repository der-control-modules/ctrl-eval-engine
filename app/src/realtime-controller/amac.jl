
using PyCall

struct AMAController <: RTController
    resolution::Dates.Period
    pyAmac
end

pushfirst!(pyimport("sys")."path", @__DIR__)
pyAmacModule = pyimport("amac")

function AMAController(controlConfig::Dict, ess, useCases::AbstractArray{UseCase})
    amac = pyAmacModule.AMACOperation(
        Dict(
            :bess_rated_kw => p_max(ess),
            :bess_rated_kWh => energy_capacity(ess),
            :bess_eta => ηRT(ess),
            :bess_soc_max => 100,
            :bess_soc_min => 0
        ),
        controlConfig
    )
    AMAController(Second(1), amac)
end

function control(ess, amac::AMAController, _::SchedulePeriod, useCases::AbstractArray{UseCase}, t, _)
    # TODO: get PV data from the variability mitigation use case
    amac.pyAmac.get_load_data(PV_data[datetime], t, SOC(ess))

    _, _, battery_power, _ = amac.pyAmac.run_model()
    return ControlSequence([battery_power], amac.resolution)
end