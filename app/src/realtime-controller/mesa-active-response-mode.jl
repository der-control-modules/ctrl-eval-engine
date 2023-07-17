using MesaEss: MesaController, VertexCurve, RampParams

struct ActiveResponseMode <: MesaMode
    activationThreshold::Float64 # Watts
    outputRatio::Float64  # Percentage
    rampParams::RampParams
end

function ActiveResponseMode(activationThreshold::Float64, outputRatio::Float64, maximumRampUp::Float64, maximumRampDown::Float64)
    return ActiveResponseMode(
        activationThreshold,
        outputRatio,
        RampParams(Dates.Second(0), Dates.Second(0), maximumRampUp, maximumRampDown, maximumRampUp, maximumRampDown)
        )
end

function modecontrol(
    mode::ActiveResponseModeMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    _,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    _
)
    duration = Dates.Second(controller.resolution)
    idxPeakLimiting = findfirst(uc -> uc isa PeakLimiting, useCases)
    idxLoadFollowing = findfirst(uc -> uc isa LoadFollowing, useCases)
    idxGenFollowing = findfirst(uc -> uc isa GenerationFollowing, useCases)
    for i in t:duration:tEnd
        currentPower = controller.wip[i]
        if idxPeakLimiting !== nothing & idxLoadFollowing === nothing & idxGenFollowing === nothing # Only peak following.
            useCase = useCases[idxPeakLimiting]
            referencePower = useCase.realtimePower
            powerPastLimit = max(referencePower - mode.activationThreshold, 0)
        elseif idxPeakLimiting === nothing & idxLoadFollowing !== nothing & idxGenFollowing === nothing # Only load following.
            useCase = useCases[idxLoadFollowing]
            referencePower = useCase.realtimeLoadPower
            powerPastLimit = max((referencePower - mode.activationThreshold) * mode.ratio / 100, 0)
        elseif idxPeakLimiting === nothing & idxLoadFollowing === nothing & idxGenFollowing !== nothing # Only generation follwing.
            useCase = useCases[idxGenFollwing]
            referencePower = useCase.realtimePower
            powerPastLimit = min((referencePower - mode.activationThreshold) * mode.ratio / 100, 0)
        else
            # How to warn or err when a disallowed useCase condition occurs. (Must have exactly one known UseCase.)
        end
        rampLimitedPower = apply_ramps(ess, mode.rampParams, currentPower, powerPastLimit)
        essLimitedPower = min(max(rampLimitedPower, p_min(ess)), p_max(ess))
        energyLimitedPower = apply_energy_limits(ess, essLimitedPower, Dates.Second(controller.resolution))
        controller.wip[i] = currentPower + energyLimitedPower
    end
end