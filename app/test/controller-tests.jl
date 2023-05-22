using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates, SOC, SOH, operate!
using CtrlEvalEngine.EnergyStorageUseCases: UseCase
using CtrlEvalEngine.EnergyStorageScheduling: end_time, schedule, ManualScheduler, SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: control, PIDController
using Dates
using JSON

@testset "PID Controller" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    tStart = floor(now(), Hour(1))
    useCases = UseCase[
        EnergyArbitrage(
            VariableIntervalTimeSeries(
                range(tStart; step=Hour(1), length=5),
                [10, 20, 1, 10]
            )
        )
    ]
    t = tStart
    progress = CtrlEvalEngine.Progress(
        0.0,
        CtrlEvalEngine.ScheduleHistory([t], Float64[]),
        CtrlEvalEngine.OperationHistory([t], Float64[], Float64[SOC(ess)], [SOH(ess)])
    )
    setting = CtrlEvalEngine.SimSetting(tStart, tStart + Hour(1))
    controller = PIDController(Minute(1), 8.0, 0.5, 0.01)

    schedulePeriod = SchedulePeriod(65.2, tStart, Hour(1))
    schedulePeriodEnd = min(end_time(schedulePeriod), tStart + Hour(1))
    spProgress = VariableIntervalTimeSeries([tStart], Float64[])
    while t < schedulePeriodEnd
        controlSequence = control(ess, controller, schedulePeriod, useCases, t, spProgress)
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
    @test true
end
