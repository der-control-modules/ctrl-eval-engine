using CtrlEvalEngine.EnergyStorageRTControl: MesaController, VertexCurve, RampParams, previous_WIP

struct AGCMode <: MesaMode
    params::MesaModeParams
    rampOrTimeConstant::Bool
    rampParams::RampParams
    minimumUsableSOC::Float64
    maximumUsableSOC::Float64
end

# TODO: This is a mock regulation_capacity function. Remove this and import when the real one is available.
function regulation_capacity(schedulePeriod)
    return 500.0
end

function modecontrol(
    mode::AGCMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries,
    currentIterationPower::Float64
)
    idxRegulation = findfirst(uc -> uc isa Regulation, useCases)
    if idxRegulation !== nothing
        regulationUC = useCases[idxRegulation]
        # Get Current Active Power Target (in Percentage, to comply with use Case -- NOTE: MESA gives a power):
        (AGCSignalPercentage, _, _) = get_period(regulationUC.AGCSignalPercentage, t)

        # Convert percentage to the actual AGC signal (in kW, not MW) based on the regulation capacity from the sceheuler.
        activePowerTarget = regulation_capacity(schedulePeriod) * AGCSignalPercentage / 100
        # Move towards the target power as approprate to time constant or ramp rate limits:
        ramping_func = mode.rampOrTimeConstant ? apply_ramps : apply_time_constants
        lastModePower = previous_WIP(mode)
        rampLimitedPower = ramping_func(ess, mode.rampParams, lastModePower, activePowerTarget)
        # Apply mode-specific energy limits.
        energyLimitedPower = apply_energy_limits(ess, rampLimitedPower, controller.resolution,
                mode.minimumUsableSOC, mode.maximumUsableSOC)
        return energyLimitedPower
    else
        # Load Following isn't selected, follow schedule
        remainingTime = EnergyStorageScheduling.end_time(schedulePeriod) - t
        return ControlSequence(
            [
                min(
                    max(p_min(ess, remainingTime), scheduledPower),
                    p_max(ess, remainingTime),
                ),
            ],
            remainingTime,
        )
    end
end