using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates, SOC, operate!
using CtrlEvalEngine.EnergyStorageUseCases: UseCase, LoadFollowing
using CtrlEvalEngine.EnergyStorageScheduling: end_time, schedule, ManualScheduler, SchedulePeriod, SchedulePeriodProgress
using CtrlEvalEngine.EnergyStorageRTControl: control, PIDController
using Dates
using JSON

@testset "PID Controller" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    tStart = floor(now(), Hour(1))
    # manSched = ManualScheduler([3.6, 65.2, 87.9, 2.4, 91.7], tStart, Hour(1))
    useCases = UseCase[
        LoadFollowing(
            VariableIntervalTimeSeries(
                range(tStart; step=Hour(1), length=5),
                [10, 20, 1, 10]
            )
        ),
    ]
    t = tStart
    progress = CtrlEvalEngine.Progress(
        0.0,
        CtrlEvalEngine.ScheduleHistory([t], Float64[]),
        CtrlEvalEngine.OperationHistory([t], Float64[], Float64[SOC(ess)])
    )
    setting = CtrlEvalEngine.SimSetting(tStart, tStart + Hour(1))
#    sched = schedule(ess, manSched, useCases, tStart)
#    CtrlEvalEngine.update_progress!(progress.schedule, sched)
    controller = PIDController(Minute(1), 1.0, 1.0, 1.0)

#     for schedulePeriod in sched
    schedulePeriod = SchedulePeriod(65.2, tStart, Hour(1))
    schedulePeriodEnd = min(end_time(schedulePeriod), tStart + Hour(1))
    spProgress = SchedulePeriodProgress(schedulePeriod)
    while t < schedulePeriodEnd
        controlSequence = control(ess, controller, schedulePeriod, useCases[1], t, spProgress)
        for (powerSetpointKw, controlDuration) in controlSequence
            actualPowerKw = operate!(ess, powerSetpointKw, controlDuration)
            CtrlEvalEngine.update_schedule_period_progress!(spProgress, actualPowerKw, controlDuration)
            t += controlDuration
            CtrlEvalEngine.update_progress!(progress, t, setting, ess, actualPowerKw)
            if t > schedulePeriodEnd
                break
            end
        end
    end
    open("controller_test_output.json","w")do f
        JSON.print(f, progress)
    end
#     end
 #   @test sVar.powerKw[2] > sVar.powerKw[3]
end
