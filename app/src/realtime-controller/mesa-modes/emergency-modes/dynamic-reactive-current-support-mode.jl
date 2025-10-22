using CtrlEvalEngine.EnergyStorageRTControl: MesaController, VertexCurve, RampParams

struct DynamicReactiveCurrentSupportMode <: MesaMode
    params::MesaModeParams
    # voltageMeter
    gradientMode::Enum
    deadbandMinimumVoltage::Float64
    deadbandMaximumVoltage::Float64
    sagGradient::Float64
    swellGradient::Float64
    smoothingFilterTime::Dates.Second
    ## Optional arguments: should we use any of these?
    # enableEventBasedReactiveCurrentSupport (if required)
    # holdTime::Dates.Millisecond (if event based reactive current support is required.)
    # blockZoneVoltage (if required, else 0.)
    # hysteresisBlockZoneVoltage (if required, else 0.)
    # blockZoneTime (if required, else 0.)
end


function modecontrol(
    mode::DynamicReactiveCurrentSupportMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries,
    currentIterationPower::Float64
)
    # TODO: Implement event-based behavior.
    # TODO: Implement blocking-zone option.

    # TODO: What use case is this really? Is VoltageControl appropriate?
    idxVoltageControl = findfirst(uc -> uc isa voltageControl, useCases)
    if idxVoltageControl !== nothing
        error("Disallowed set of UseCases: Only VoltageControl UseCase may be used with the MESA Reactive Current Support Mode.")
    else
        useCase = useCases[idxVoltageControl]
    end
    (measuredVoltage, _, _) = get_period(useCase.meteredVoltage, t)
    movingAverageVoltage = mean(useCase.pvGenProfile, t - mode.smoothingFilterTime, t)
    percentDeltaVoltage = (measuredVoltage - movingAverageVoltage) / ess.referenceVoltage

    # Note that deadbandMinimumVoltage and deadbandMaximumVoltage are signed percentage offsets of the reference voltage.
    lowerDeadband = mode.gradientMode == 2 ? ess.referenceVoltage : ess.referenceVoltage + (ess.referenceVoltage * mode.deadbandMinimumVoltage / 100)
    upperDeadband = mode.gradientMode == 2 ? ess.referenceVoltage : ess.referenceVoltage + (ess.referenceVoltage * mode.deadbandMaximumVoltage / 100)

    if percentDeltaVoltage < lowerDeadband
        reactiveCurrentSupportGradient = sagGradient
    elseif percentDeltaVoltage > upperDeadband
        reactiveCurrentSupportGradient = swellGradient
    else
        reactiveCurrentSupportGradient =  0.0
    end
    
    percentReactiveCurrent = reactiveCurrentSupportGradient * percentDeltaVoltage
    additionalReactiveCurrent = percentReactiveCurrent * ess.maximumRatedCurrent
    # How to handle reactive current conversions and energy limits?
    return energyLimitedPower
end
