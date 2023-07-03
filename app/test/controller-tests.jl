using CtrlEvalEngine
using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates, SOC, SOH, operate!
using CtrlEvalEngine.EnergyStorageUseCases: LoadFollowing, UseCase
using CtrlEvalEngine.EnergyStorageScheduling: end_time, schedule, ManualScheduler, SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: control, PIDController
using Dates
using JSON
using Test
using DiscretePIDs

@testset "PID Controller" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    tStart = floor(now(), Hour(1))
    useCases = UseCase[
        LoadFollowing(
            Dict(
                "realtimeLoadPower" =>
                    [
                        Dict("DateTime" => tStart, "Power" => 10),
                        Dict("DateTime" => tStart + Minute(5), "Power" => 20),
                        Dict("DateTime" => tStart + Minute(10), "Power" => 1),
                        Dict("DateTime" => tStart + Minute(15), "Power" => 10),
                    ],
                "forecastLoadPower" =>
                    [
                        Dict("DateTime" => tStart, "Power" => 15),
                        Dict("DateTime" => tStart + Minute(5), "Power" => 20),
                        Dict("DateTime" => tStart + Minute(10), "Power" => 1),
                        Dict("DateTime" => tStart + Minute(15), "Power" => 10),
                    ]
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
    println("Creating controller NOW!")
    controller = PIDController(Second(1), 0.5, 0.5, 0.9)
    schedulePeriod = SchedulePeriod(65.2, tStart, Minute(15))
    schedulePeriodEnd = min(end_time(schedulePeriod), tStart + Hour(1))
    spProgress = VariableIntervalTimeSeries([tStart], Float64[])
    while t < schedulePeriodEnd
        controlSequence = control(ess, controller, schedulePeriod, useCases, t, spProgress)
        # controlSequence = control(ess, controller, schedulePeriod, useCases, t, spProgress)
        println("Control Sequence: ", controlSequence)
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
    open("controller_test_output5.json","w")do f
        JSON.print(f, progress)
    end
 #   @test sVar.powerKw[2] > sVar.powerKw[3]
end
