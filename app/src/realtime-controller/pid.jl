using Dates, DiscretePIDs
using CtrlEvalEngine.EnergyStorageSimulators: EnergyStorageSystem
using CtrlEvalEngine.EnergyStorageUseCases: LoadFollowing
using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod

struct PIDController <: RTController
    resolution::Dates.Period
    Kp::AbstractFloat
    Ti::AbstractFloat
    Td::AbstractFloat
end

function control(ess::EnergyStorageSystem, controller::PIDController,
     schedulePeriod::SchedulePeriod, useCase::LoadFollowing, t,
      spProgress::SchedulePeriodProgress)
    # TODO: How should we really convert from resolution to sample_time? Seconds?
    pid = DiscretePID(; K=controller.Kp, Ts=controller.resolution.value,Ti=controller.Ti, Td=controller.Td)
    control_signals = []
    set_point = average_power(schedulePeriod)
    measured_value, _, _ = CtrlEvalEngine.get_period(useCase.loadPower, t)
    if isempty(spProgress.powerKw)
        process_variable = measured_value
    else
        process_variable = measured_value - spProgress.powerKw[end]
    end
    control_signal = pid(set_point, process_variable)
    push!(control_signals, control_signal)
    print(["spProgress.powerKw:", spProgress.powerKw, "set_point:", set_point, "measured_value:", measured_value, "process_variable:", process_variable, "control_signal:", control_signal])
    return ControlSequence(control_signals, controller.resolution)
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
