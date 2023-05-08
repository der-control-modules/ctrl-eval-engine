using Dates, DiscretePIDs
using CtrlEvalEngine.EnergyStorageSimulators: EnergyStorageSystem
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod

struct PIDController <: RTController
    resolution::Dates.Period
    Kp::Float64
    Ti::Float64
    Td::Float64
end

function control(
    ess::EnergyStorageSystem,
    controller::PIDController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries
)
    pid = DiscretePID(
        K=controller.Kp,
        Ts=Dates.value(convert(Second, controller.resolution)),
        Ti=controller.Ti,
        Td=controller.Td
    )
    control_signals = []
    set_point = average_power(schedulePeriod)

    # TODO: handle LoadFollowing as a use case
    # measured_value, _, _ = CtrlEvalEngine.get_period(useCase.loadPower, t)
    process_variable = if isempty(spProgress.value)
        set_point
    else
        CtrlEvalEngine.mean(spProgress)
    end
    control_signal = pid(set_point, process_variable)
    push!(control_signals, control_signal)
    # print(["spProgress.powerKw:", spProgress.powerKw, "set_point:", set_point, "measured_value:", measured_value, "process_variable:", process_variable, "control_signal:", control_signal])
    return ControlSequence([control_signal], controller.resolution)
end


# function control(ess::EnergyStorageSystem, controller::PIDController,
#      schedulePeriod::SchedulePeriod, useCase::LoadFollowing, t,
#       spProgress::SchedulePeriodProgress)
#     pid = DiscretePID(; controller.Kp, controller.resolution, controller.Ti, controller.Td)
#     tStart = start_time(schedulePeriod)
#     tEnd = end_time(schedulePeriod)
#     control_signals = []
#     set_point = average_power(schedulePeriod)
#     process_variable, _, _ = get_period(useCase.loadPower, tStart)
#     current_powers = [load for load in useCase.loadPower if tStart <= load[2] < tEnd]
#     for (measured_value, load_start, load_end) in current_powers
#         t_now = load_start
#         while t_now < load_end
#             control_signal = pid(set_point, process_variable)
#             process_variable = measured_value + control_signal
#             control_signals.append!(control_signal)
#             t_now += controller.resolution
#         end
#     end
#     return ControlOperations(control_signals, controller.resolution)
# end
