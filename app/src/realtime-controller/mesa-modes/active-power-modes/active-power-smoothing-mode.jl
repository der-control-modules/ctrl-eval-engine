using CtrlEvalEngine.EnergyStorageRTControl: MesaController, VertexCurve, RampParams

struct ActivePowerSmoothingMode <: MesaMode
    params::MesaModeParams
    smoothingGradient::Float64
    lowerSmoothingLimit::Float64
    upperSmoothingLimit::Float64
    smoothingFilterTime::Dates.Period
    rampParams::RampParams
end

function ActivePowerSmoothingMode(
    params::MesaModeParams,
    smoothingGradient::Float64,
    lowerSmoothingLimit::Float64,
    upperSmoothingLimit::Float64,
    dischargeMaximumRampUp::Float64,
    dischargeMaximumRampDown::Float64,
    chargeMaximumRampUp::Float64,
    chargeMaximumRampDown::Float64
    )
return ActivePowerSmoothingMode(
    params, smoothingGradient, lowerSmoothingLimit, upperSmoothingLimit, smoothingFilterTime,
    RampParams(Dates.Second(0), Dates.Second(0), dischargeMaximumRampUp, dischargeMaximumRampDown, chargeMaximumRampUp, chargeMaximumRampDown)
)
end


function modecontrol(
    mode::ActivePowerSmoothingMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    _,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    _,
    _
)
    idxPowerSmoothing = findfirst(uc -> uc isa VariabilityMitigation, useCases)
    if idxPowerSmoothing !== nothing
        error("Disallowed set of UseCases: Only Variability Mitigation UseCase may be used with the MESA Power Smoothing Mode.")
    else
        useCase = useCases[idxPowerSmoothing]
    end
    (referencePower, _, _) = get_period(useCase.pvGenProfile, t)
    movingAveragePower = mean(useCase.pvGenProfile, t - mode.smoothingFilterTime, t)
    deltaWattage = referencePower - movingAveragePower
    additionalWatts = lowerSmoothingLimit < deltaWattage < upperSmoothingLimit ? 0.0 : smoothingGradient * deltaWattage

    previousPower = previous_WIP(mode)
    rampLimitedPower = apply_ramps(ess, mode.rampParams, previousPower, additionalWatts)
    essLimitedPower = min(max(rampLimitedPower, p_min(ess)), p_max(ess))
    energyLimitedPower = apply_energy_limits(ess, essLimitedPower, Dates.Second(controller.resolution))
    return energyLimitedPower
end
