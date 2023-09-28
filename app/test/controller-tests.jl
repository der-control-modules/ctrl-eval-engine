using CtrlEvalEngine
using CtrlEvalEngine.EnergyStorageSimulators:
    LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates, SOC, SOH, operate!
using CtrlEvalEngine.EnergyStorageUseCases
using CtrlEvalEngine.EnergyStorageUseCases: RegulationPricePoint

using CtrlEvalEngine.EnergyStorageScheduling: schedule, ManualScheduler, SchedulePeriod
using CtrlEvalEngine.EnergyStorageRTControl:
    control,
    PIDController,
    AMAController,
    MesaController,
    MesaModeParams,
    RampParams,
    ActiveResponseMode,
    ChargeDischargeStorageMode,
    ActivePowerLimitMode,
    AGCMode,
    RuleBasedController
using Dates
using JSON
using Test

function run_controller(ess, controller, schedulePeriod, useCases, tStart)
    t = tStart
    opHist = CtrlEvalEngine.OperationHistory([t], Float64[], Float64[SOC(ess)], [SOH(ess)])
    setting = CtrlEvalEngine.SimSetting(tStart, tStart + Hour(1))
    schedulePeriodEnd = min(end_time(schedulePeriod), tStart + Hour(1))
    spProgress = VariableIntervalTimeSeries([tStart], Float64[])
    while t < schedulePeriodEnd
        controlSequence = control(ess, controller, schedulePeriod, useCases, t, spProgress)
        for (powerSetpointKw, _, controlPeriodEnd) in controlSequence
            controlDuration = controlPeriodEnd - t
            actualPowerKw = operate!(ess, powerSetpointKw, controlDuration)
            CtrlEvalEngine.update_schedule_period_progress!(
                spProgress,
                actualPowerKw,
                controlDuration,
            )
            t += controlDuration
            CtrlEvalEngine.update_operation_history!(opHist, t, ess, actualPowerKw)
            if t > schedulePeriodEnd
                break
            end
        end
    end
end

ess =
    LiIonBattery(LFP_LiIonBatterySpecs(500, 10000, 0.85, 2000), LiIonBatteryStates(0.5, 0))
tStart = floor(now(), Hour(1))

@testset "AGC MESA Mode" begin
    useCases = UseCase[Regulation(
        FixedIntervalTimeSeries(
            tStart,
            Dates.Second(4),
            [
                0.5080047394,
                0.5080047394,
                0.5080047394,
                0.5080047394,
                0.5080047394,
                0.5080047394,
                0.5080047394,
                0.5080047394,
                0.6667162504,
                0.6667162504,
                0.6667162504,
                0.6667162504,
                0.6667162504,
                0.6667162504,
                0.6667162504,
                0.6667162504,
                0.7466479844,
                0.7466479844,
                0.9304748861,
                0.9304548861,
                0.931176534,
                0.931176534,
                0.9337098728,
                0.9337098728,
                0.9353773848,
                0.9353773848,
                0.9353773848,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.1019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
                -0.9019101319,
            ],
        ),
        FixedIntervalTimeSeries(tStart, Dates.Hour(1), [RegulationPricePoint(0.05, 0.42)]),
        50.0,
    )]
    schedulePeriod = SchedulePeriod(65.2, tStart, Second(268), 0.0, 0.0, 500.0)
    controller = MesaController(
        [AGCMode(MesaModeParams(1), true, RampParams(100, 200, 100, 200), 40.0, 60.0)],
        Dates.Second(4),
    )
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test all(
        .≈(controller.wip.value , [
            50.0,
            100.0,
            150.0,
            200.0,
            250.0,
            254.0,
            254.0,
            254.0,
            304.0,
            333.0,
            333.0,
            333.0,
            333.0,
            333.0,
            333.0,
            333.0,
            373.0,
            373.0,
            423.0,
            465.0,
            466.0,
            466.0,
            467.0,
            467.0,
            468.0,
            468.0,
            468.0,
            368.0,
            268.0,
            168.0,
            68.0,
            -32.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -51.0,
            -151.0,
            -251.0,
            -351.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0,
            -451.0
            ],
        atol=0.5
        )
    )
end

@testset "Charge Discharge Storage MESA Mode" begin
    useCases = UseCase[]
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Hour(1))

    # Test that mode follows the specified power percentage (53% of 500kW is 265kW).
    controller = MesaController(
        [
            ChargeDischargeStorageMode(
                MesaModeParams(1),
                true,
                RampParams(100.0, 200.0, 100.0, 200.0),
                20.0,
                80.0,
                53.0,
            ),
        ],
        Dates.Minute(5),
    )
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test all(
        controller.wip.value .==
        [50.0, 100.0, 150.0, 200.0, 250.0, 265.0, 265.0, 265.0, 265.0, 265.0, 265.0, 265.0],
    )

    # Test that mode follows the schedule if a power percentage is not specified .
    controller = MesaController(
        [
            ChargeDischargeStorageMode(
                MesaModeParams(1),
                true,
                RampParams(100.0, 200.0, 100.0, 200.0),
                20.0,
                80.0,
                nothing,
            ),
        ],
        Dates.Minute(5),
    )
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test all(
        controller.wip.value .==
        [50.0, 65.2, 65.2, 65.2, 65.2, 65.2, 65.2, 65.2, 65.2, 65.2, 65.2, 65.2],
    )

    # Test charging schedule (negative power):
    # Test that mode follows the schedule if a power percentage is not specified .
    controller = MesaController(
        [
            ChargeDischargeStorageMode(
                MesaModeParams(1),
                true,
                RampParams(100.0, 200.0, 100.0, 200.0),
                20.0,
                80.0,
                nothing,
            ),
        ],
        Dates.Minute(5),
    )
    schedulePeriod = SchedulePeriod(-65.2, tStart; duration = Hour(1))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test all(
        controller.wip.value .== [
            -65.2,
            -65.2,
            -65.2,
            -65.2,
            -65.2,
            -65.2,
            -65.2,
            -65.2,
            -65.2,
            -65.2,
            -65.2,
            -65.2,
        ],
    )
end

@testset "Active Power Limit MESA Mode" begin
    useCases = UseCase[]
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Hour(1))
    rampParams = RampParams(100.0, 200.0, 100.0, 200.0)

    # Test Discharge Limit:
    controller = MesaController(
        [
            ChargeDischargeStorageMode(
                MesaModeParams(1),
                true,
                rampParams,
                20.0,
                80.0,
                nothing,
            ),
            ActivePowerLimitMode(MesaModeParams(2), 2.0, 1.0),
        ],
        Dates.Minute(5),
    )
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Hour(1))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test all(
        controller.wip.value .==
        [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0],
    )

    # Test Charge Limit:
    controller = MesaController(
        [
            ChargeDischargeStorageMode(
                MesaModeParams(1),
                true,
                rampParams,
                20.0,
                80.0,
                nothing,
            ),
            ActivePowerLimitMode(MesaModeParams(2), 2.0, 1.0),
        ],
        Dates.Minute(5),
    )
    schedulePeriod = SchedulePeriod(-65.2, tStart; duration = Hour(1))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test all(
        controller.wip.value .== [
            -10.0,
            -10.0,
            -10.0,
            -10.0,
            -10.0,
            -10.0,
            -10.0,
            -10.0,
            -10.0,
            -10.0,
            -10.0,
            -10.0,
        ],
    )
end

@testset "PeakLimiting MESA Mode" begin
    useCases = UseCase[PeakLimiting(
        30,
        FixedIntervalTimeSeries(
            tStart,
            Dates.Minute(5),
            [10, 20, 30, 40, 50, 40, 30, 20, 10, 0, -10, -20],
        ),
    )]
    controller = MesaController(
        [ActiveResponseMode(MesaModeParams(1), 30.0, 1.0, 1000.0, 1000.0)],
        Dates.Minute(5),
    )
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Hour(1))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)

    @test all(
        controller.wip.value .==
        [0.0, 0.0, 0.0, 10.0, 20.0, 10.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    )
end

@testset "LoadFollowing MESA Mode" begin
    useCases = UseCase[LoadFollowing(
        FixedIntervalTimeSeries(tStart, Dates.Minute(60), [30]),
        FixedIntervalTimeSeries(
            tStart,
            Dates.Minute(5),
            [10, 20, 30, 40, 50, 40, 30, 20, 10, 0, -10, -20],
        ),
    )]
    controller = MesaController(
        [ActiveResponseMode(MesaModeParams(1), 30.0, 10.0, 1000.0, 1000.0)],
        Dates.Minute(5),
    )
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Hour(1))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test all(
        controller.wip.value .==
        [0.0, 0.0, 0.0, 1.0, 2.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    )
end

@testset "GenerationFollowing MESA Mode" begin
    useCases = UseCase[GenerationFollowing(
        FixedIntervalTimeSeries(tStart, Dates.Minute(60), [30]),
        FixedIntervalTimeSeries(
            tStart,
            Dates.Minute(5),
            [10, 20, 30, 40, 50, 40, 30, 20, 10, 0, -10, -20],
        ),
    )]
    controller = MesaController(
        [ActiveResponseMode(MesaModeParams(1), 30.0, 10.0, 1000.0, 1000.0)],
        Dates.Minute(5),
    )
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Hour(1))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    # @test controller.wip.value ==
    #       [-2.0, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1.0, -2.0, -3.0, -4.0, -5.0]
end

@testset "PID Controller" begin
    useCases = UseCase[EnergyArbitrage(
        VariableIntervalTimeSeries(
            range(tStart; step = Hour(1), length = 5),
            [10, 20, 1, 10],
        ),
    )]
    controller = PIDController(Minute(1), 8.0, 0.5, 0.01)
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Hour(1))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test true
end

@testset "PID Controller" begin
    useCases = UseCase[LoadFollowing(
        FixedIntervalTimeSeries(tStart, Minute(5), [10, 20, 1, 10]),
        FixedIntervalTimeSeries(tStart, Minute(5), [15, 20, 1, 10]),
    )]
    controller = PIDController(Second(1), 0.5, 0.5, 0.9)
    schedulePeriod = SchedulePeriod(65.2, tStart, duration=Minute(15))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test true
end

@testset "AMAC" begin
    useCases = [
        VariabilityMitigation(
            FixedIntervalTimeSeries(
                tStart + Minute(20),
                Minute(5),
                [60.0, 110.6, 200.0, 90.0, 20.0, 92.4, 150.7],
            ),
            300,
        ),
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
        useCases,
    )
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Hour(1))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test true
end

@testset "Rule-based Controller" begin
    useCases = UseCase[LoadFollowing(
        FixedIntervalTimeSeries(tStart, Minute(15), [20, 1, 10, 4]),
        FixedIntervalTimeSeries(
            tStart,
            Minute(5),
            [20.4, 18.2, 15, 6, 3, 0.5, 7, 6, 10, 11, 3, 2, 2.2],
        ),
    )]
    controller = RuleBasedController(1.5)
    schedulePeriod = SchedulePeriod(65.2, tStart; duration = Minute(15))
    run_controller(ess, controller, schedulePeriod, useCases, tStart)
    @test true
end