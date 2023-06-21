
using PyCall
using CtrlEvalEngine: start_time, end_time

struct AMAController <: RTController
    pyAmac
end

function AMAController(controlConfig::Dict)
    pyAmac = py"AMACOperation"(
        # Dict(
        #     :bess_rated_kw => p_max(ess),
        #     :bess_rated_kWh => e_max(ess),
        #     :bess_eta => ηRT(ess),
        #     :bess_soc_max => 100,
        #     :bess_soc_min => 0
        # ),
        controlConfig
    )
    AMAController(pyAmac)
end

function control(ess, amac::AMAController, sp::SchedulePeriod, useCases::AbstractArray{UseCase}, t::DateTime, _::VariableIntervalTimeSeries)
    amac.pyAmac.get_bess_data(
        p_max(ess),
        e_max(ess) - e_min(ess),
        ηRT(ess),
        SOC(ess),
        100,
        e_min(ess) / e_max(ess) * 100,
    )

    idxVM = findfirst(uc -> uc isa VariabilityMitigation, useCases)

    if isnothing(idxVM)
        # If VariabilityMitigation use case isn't selected, fall back to passive control according to schedule
        return ControlSequence([sp.powerKw], sp.duration)
    end

    ucVM = useCases[idxVM]
    if start_time(ucVM.pvGenProfile) > t
        # Passive control until start of PV generation or end of SchedulePeriod, whichever comes first
        return ControlSequence(
            [sp.powerKw],
            min(start_time(ucVM.pvGenProfile), EnergyStorageScheduling.end_time(sp)) - t
        )
    end

    currentPvGen, _, _ = get_period(ucVM.pvGenProfile, t)
    if isnothing(currentPvGen)
        # Passive control to the end of SchedulePeriod if PV generation profile has ended
        return ControlSequence([sp.powerKw], EnergyStorageScheduling.end_time(sp) - t)
    end

    # Active control if PV generation is present
    amac.pyAmac.get_load_data(currentPvGen, t)
    _, _, battery_power, _ = amac.pyAmac.run_model()
    battery_power = min(max(p_min(ess), battery_power + sp.powerKw), p_max(ess))
    return ControlSequence([battery_power], ucVM.pvGenProfile.resolution)
end