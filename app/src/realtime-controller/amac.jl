
using PyCall
using CtrlEvalEngine: start_time, end_time

struct AMAController <: RTController
    pyAmac::Any
    passive::Bool
end

function AMAController(
    controlConfig::Dict,
    ess::EnergyStorageSystem,
    useCases::AbstractArray{<:UseCase},
)
    pyAmac = py"AMACOperation"(controlConfig)
    pyAmac.set_bess_data(
        p_max(ess),
        e_max(ess) - e_min(ess),
        ηRT(ess),
        100,
        e_min(ess) / e_max(ess) * 100,
    )

    idxVM = findfirst(uc -> uc isa VariabilityMitigation, useCases)
    if !isnothing(idxVM)
        ucVM::VariabilityMitigation = useCases[idxVM]
        # TODO: update data interval based on input profile
        # pyAmac.set_data_interval(ucVM.pvGenProfile.resolution / Second(1))
        pyAmac.set_PV_rated_power(ucVM.ratedPowerKw)
    end

    # If VariabilityMitigation use case isn't selected, fall back to passive control according to schedule
    AMAController(pyAmac, isnothing(idxVM))
end

function control(
    ess,
    amac::AMAController,
    sp::SchedulePeriod,
    useCases::AbstractArray{<:UseCase},
    t::DateTime,
    ::VariableIntervalTimeSeries,
)
    if amac.passive
        # Fall back to passive control according to schedule
        return ControlSequence([sp.powerKw], sp.duration)
    end

    idxVM = findfirst(uc -> uc isa VariabilityMitigation, useCases)
    ucVM::VariabilityMitigation = useCases[idxVM]
    if start_time(ucVM.pvGenProfile) > t
        # Passive control until start of PV generation or end of SchedulePeriod, whichever comes first
        return ControlSequence(
            [sp.powerKw],
            min(start_time(ucVM.pvGenProfile), EnergyStorageScheduling.end_time(sp)) - t,
        )
    end

    if t ≥ end_time(ucVM.pvGenProfile)
        # Passive control to the end of SchedulePeriod if PV generation profile has ended
        return ControlSequence([sp.powerKw], EnergyStorageScheduling.end_time(sp) - t)
    end

    # Active control if PV generation is present
    currentPvGen, _, tEndPvGenPeriod = get_period(ucVM.pvGenProfile, t)
    controlDuration = tEndPvGenPeriod - t
    amac.pyAmac.set_load_data(currentPvGen, t)
    battery_power = amac.pyAmac.run_model(SOC(ess) * 100)
    battery_power = min(
        max(p_min(ess, controlDuration), battery_power + sp.powerKw),
        p_max(ess, controlDuration),
    )
    @debug "Active AMAC" t controlDuration maxlog=20
    return ControlSequence([battery_power], controlDuration)
end