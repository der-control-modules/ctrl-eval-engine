using Dates, DiscretePIDs
using CtrlEvalEngine.EnergyStorageSimulators: EnergyStorageSystem
using CtrlEvalEngine.EnergyStorageUseCases: UseCase, LoadFollowing
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod

struct PIDController <: RTController
    resolution::Dates.Period
    Kp::Float64
    Ti::Float64
    Td::Float64
end

function control(
    ess::EnergyStorageSystem,
    pid,
    # controller::PIDController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries
)
    # pid = DiscretePID(
    #     K=controller.Kp,
    #     Ts=Dates.value(convert(Second, controller.resolution)),
    #     Ti=controller.Ti,
    #     Td=controller.Td
    # )
    control_signals = []
    scheduled_bess_power = average_power(schedulePeriod)
    # actual_bess_power = isempty(spProgress.value) ? 0.0 : CtrlEvalEngine.mean(spProgress)
    actual_bess_power = isempty(spProgress.value) ? 0.0 : last(spProgress.value)
    # actual_bess_power = isempty(spProgress.value) ? scheduled_bess_power : last(spProgress.value)
    println("\nAt time:", t)
    println("Scheduled BESS Power: ", scheduled_bess_power)
    println("Actual BESS Power: ", actual_bess_power)
    idxloadFollowing = findfirst(uc -> uc isa LoadFollowing, useCases)
    if idxloadFollowing !== nothing
        lf = useCases[idxloadFollowing]
        expected_load, _, _ = CtrlEvalEngine.get_period(lf.forecastLoadPower, t)
        actual_load, _, _ = CtrlEvalEngine.get_period(lf.realtimeLoadPower, t)
        # set_point = expected_load - scheduled_bess_power
        # process_variable = actual_load - actual_bess_power
        set_point = scheduled_bess_power - expected_load
        process_variable = actual_bess_power - actual_load

        println("WE ARE LOAD FOLLOWING!")
        println("Expected Load: ", expected_load)
        println("Actual Load: ", actual_load)
        println("Set Point: ", set_point)
        println("Process Variable: ", process_variable)
    else
        println("NO USE CASES KNOWN....")
        set_point = scheduled_bess_power
        process_variable = actual_bess_power
    end
    control_signal = pid(set_point, process_variable)
    println("Control Signal: ", control_signal)
    push!(control_signals, control_signal)
    return ControlSequence([control_signal], Second(pid.Ts)) 
end
