using CtrlEvalEngine
using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates, SOC, SOH, operate!
using CtrlEvalEngine.EnergyStorageUseCases: LoadFollowing, UseCase
using CtrlEvalEngine.EnergyStorageUseCases
using CtrlEvalEngine.EnergyStorageScheduling: end_time, schedule, ManualScheduler, SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: control, PIDController, AMAController
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
    opHist = CtrlEvalEngine.OperationHistory([t], Float64[], Float64[SOC(ess)], [SOH(ess)])
    setting = CtrlEvalEngine.SimSetting(tStart, tStart + Hour(1))
    println("Creating controller NOW!")
    controller = PIDController(Second(1), 0.5, 0.5, 0.9)
    schedulePeriod = SchedulePeriod(65.2, tStart, Minute(15))
    schedulePeriodEnd = min(end_time(schedulePeriod), tStart + Hour(1))
    spProgress = VariableIntervalTimeSeries([tStart], Float64[])
    while t < schedulePeriodEnd
        controlSequence = control(ess, controller, schedulePeriod, useCases, t, spProgress)
        for (powerSetpointKw, controlDuration) in controlSequence
            actualPowerKw = operate!(ess, powerSetpointKw, controlDuration)
            CtrlEvalEngine.update_schedule_period_progress!(spProgress, actualPowerKw, controlDuration)
            t += controlDuration
            CtrlEvalEngine.update_operation_history!(opHist, t, ess, actualPowerKw)
            if t > schedulePeriodEnd
                break
            end
        end
    end
    @test true
end

@testset "AMAC" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    tStart = floor(now(), Hour(1))
    useCases = [
        VariabilityMitigation(
            FixedIntervalTimeSeries(
                tStart + Minute(20),
                Minute(5),
                [60.0, 110.6, 200.0, 90.0, 20.0, 92.4, 150.7]
            ),
            300
        )
    ]
    controller = AMAController(
        Dict(
            "dampingParameter" => 8.0,
            "maximumAllowableWindowSize" => 2100,
            "maximumPvPower" => 300,
            "maximumAllowableVariabilityPct" => 50,
            "referenceVariabilityPct" => 10,
            "minimumAllowableVariabilityPct" => 5,
            "referenceSocPct" => 50.0,
        ),
        ess,
        useCases
    )

    schedulePeriod = SchedulePeriod(65.2, tStart, Hour(1))
    schedulePeriodEnd = min(end_time(schedulePeriod), tStart + Hour(1))
    spProgress = VariableIntervalTimeSeries([tStart], Float64[])
    t = tStart
    while t < schedulePeriodEnd
        controlSequence = control(ess, controller, schedulePeriod, useCases, t, spProgress)
        for (powerSetpointKw, controlDuration) in controlSequence
            actualPowerKw = operate!(ess, powerSetpointKw, controlDuration)
            CtrlEvalEngine.update_schedule_period_progress!(spProgress, actualPowerKw, controlDuration)
            t += controlDuration
            if t > schedulePeriodEnd
                break
            end
        end
    end
    @test true
end
