
struct PassThroughController <: RTController end

function control(
    _,
    controller::PassThroughController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t,
    _,
)
    idxReg = findfirst(uc -> uc isa Regulation, useCases)
    if idxReg !== nothing
        # Regulation is selected
        ucReg::Regulation = useCases[idxReg]
        regCap = regulation_capacity(schedulePeriod)
        return FixedIntervalTimeSeries(t, remainingTime, [scheduled_bess_power]) +
               extract(ucReg.AGCSignalPu, t, end_time(schedulePeriod)) * regCap
    end

    @debug "Control sequence updated" controlOps
    return FixedIntervalTimeSeries(
        t,
        end_time(schedulePeriod) - t,
        [average_power(schedulePeriod)],
    )
end