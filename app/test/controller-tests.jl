using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates, SOC, SOH, operate!
using CtrlEvalEngine.EnergyStorageUseCases
using CtrlEvalEngine.EnergyStorageScheduling: end_time, schedule, ManualScheduler, SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl: control, PIDController, AMAController, MesaController, MesaModeParams, ActiveResponseMode
using Dates
using JSON

@testset "PeakLimiting MESA Controller" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 100000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    tStart = floor(now(), Hour(1))
    useCases = UseCase[
        PeakLimiting(
            30,
            FixedIntervalTimeSeries(
                tStart,
                Dates.Minute(5),
                [10, 20, 30, 40, 50, 40, 30, 20, 10, 0, -10, -20]
            )
        )
    ]
    t = tStart
    opHist = CtrlEvalEngine.OperationHistory([t], Float64[], Float64[SOC(ess)], [SOH(ess)])
    setting = CtrlEvalEngine.SimSetting(tStart, tStart + Hour(1))
    controller = MesaController(
        [ActiveResponseMode(MesaModeParams(1, Dates.Second(1), Dates.Second(1), Dates.Second(1)), 30.0, 1.0, 1000.0, 1000.0)],
         Dates.Minute(5)
         )
    schedulePeriod = SchedulePeriod(65.2, tStart, Hour(1))
    schedulePeriodEnd = min(end_time(schedulePeriod), tStart + Hour(1))
    spProgress = VariableIntervalTimeSeries([tStart], Float64[])

    while t < schedulePeriodEnd
        controlSequence = control(ess, controller, schedulePeriod, useCases, t, spProgress)
        print('\n', "at time: ", t, " controlSequence is: ", controlSequence)
        for (powerSetpointKw, controlDuration) in controlSequence
            actualPowerKw = operate!(ess, powerSetpointKw, controlDuration)
            print('\n')
            print(actualPowerKw)
            print('\n')
            CtrlEvalEngine.update_schedule_period_progress!(spProgress, actualPowerKw, controlDuration)
            t += controlDuration
            CtrlEvalEngine.update_operation_history!(opHist, t, ess, actualPowerKw)
            if t > schedulePeriodEnd
                break
            end
        end
    end
    print('\n')
    print(spProgress)
    print('\n')
    print(controller.modes[1].params.modeWIP)
    print('\n')
    print(controller.wip)
    print('\n')
    @test true
end

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
    opHist = CtrlEvalEngine.OperationHistory([t], Float64[], Float64[SOC(ess)], [SOH(ess)])
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