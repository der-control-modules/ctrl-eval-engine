using CtrlEvalEngine.EnergyStorageRTControl: MesaController, VertexCurve, RampParams

struct ActiveResponseMode <: MesaMode
    params::MesaModeParams
    activationThreshold::Float64 # Watts
    outputRatio::Float64  # Percentage
    rampParams::RampParams
end

function ActiveResponseMode(params::MesaModeParams, activationThreshold::Float64, outputRatio::Float64, maximumRampUp::Float64, maximumRampDown::Float64)
    return ActiveResponseMode(
        params,
        activationThreshold,
        outputRatio,
        RampParams(Dates.Second(0), Dates.Second(0), maximumRampUp, maximumRampDown, maximumRampUp, maximumRampDown)
        )
end

function modecontrol(
    mode::ActiveResponseMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    _,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    _
)
    idxPeakLimiting = findfirst(uc -> uc isa PeakLimiting, useCases)
    idxLoadFollowing = findfirst(uc -> uc isa LoadFollowing, useCases)
    idxGenFollowing = findfirst(uc -> uc isa GenerationFollowing, useCases)
    currentPower = last(mode.params.modeWIP.value)
    if idxPeakLimiting !== nothing && idxLoadFollowing === nothing && idxGenFollowing === nothing # Only peak following.
        useCase = useCases[idxPeakLimiting]
        (referencePower, _, _) = get_period(useCase.realtimePower, t)
        print('\n', "At time: ", t, " referencePower is: ", referencePower)
        powerPastLimit = max(referencePower - mode.activationThreshold, 0)
        print(" powerPastLimit is: ", powerPastLimit, '\n')
    elseif idxPeakLimiting === nothing && idxLoadFollowing !== nothing && idxGenFollowing === nothing # Only load following.
        useCase = useCases[idxLoadFollowing]
        (referencePower, _, _) = get_period(useCase.realtimeLoadPower, t)
        powerPastLimit = max((referencePower - mode.activationThreshold) * mode.ratio / 100, 0)
    elseif idxPeakLimiting === nothing && idxLoadFollowing === nothing && idxGenFollowing !== nothing # Only generation follwing.
        useCase = useCases[idxGenFollwing]
        (referencePower, _, _) = get_period(useCase.realtimePower, t)
        powerPastLimit = min((referencePower - mode.activationThreshold) * mode.ratio / 100, 0)
    else
        if count([idxGenFollowing, idxLoadFollowing, idxPeakLimiting]) > 1
            error("Disallowed set of UseCases: Only one of \"PeakLimiting\", \"LoadFollowing\",
             and \"GenerationFollowing\" may be used with the MESA Active Response Mode.")
        end
        powerPastLimit = 0.0
    end
    rampLimitedPower = apply_ramps(ess, mode.rampParams, currentPower, powerPastLimit)
    essLimitedPower = min(max(rampLimitedPower, p_min(ess)), p_max(ess))
    energyLimitedPower = apply_energy_limits(ess, essLimitedPower, Dates.Second(controller.resolution))
    return energyLimitedPower
end
