
using JSON
using Dates
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageScheduling
using CtrlEvalEngine.EnergyStorageRTControl
using CtrlEvalEngine.EnergyStorageUseCases

@testset "ESS Input" begin
    inputDict = JSON.parse("""
        {
            "calculationType": "duration",
            "duration": 4,
            "powerCapacityUnit": "kw",
            "powerCapacityValue": 123,
            "totalInstallCost": "1578",
            "installCostCurrency": "usd",
            "energyCapacity": null,
            "batteryType": "lfp-lithium-ion",
            "roundtripEfficiency": 0.86,
            "cycleLife": 2000
        }""")

    ess = get_ess(inputDict)
    @test SOC(ess) ≥ 0 && SOC(ess) ≤ 1
    @test SOH(ess) ≥ 0 && SOH(ess) ≤ 1
end

@testset "Use Case Input" begin
    inputDict = JSON.parse("""
        {
            "Power Smoothing": {
                "data": {
                    "pvGenProfile": {
                        "DateTime": [
                            "2018-01-21T00:00",
                            "2018-01-21T00:01",
                            "2018-01-21T00:02",
                            "2018-01-21T00:03"
                        ],
                        "Power": [
                            351.54,
                            351.5,
                            35.54,
                            51.54
                        ]
                    },
                    "ratedPowerKw": 500
                }
            }
        }"""
    )
    useCases = get_use_cases(inputDict, CtrlEvalEngine.SimSetting(DateTime(2018), DateTime(2019), 10))
    @test useCases isa AbstractVector{<:UseCase}
    @test useCases[1] isa VariabilityMitigation
    @test useCases[1].pvGenProfile.resolution == Minute(1)
    @test useCases[1].ratedPowerKw == 500
end

@testset "Scheduler Input" begin
    @testset "MockScheduler" begin
        inputDict = JSON.parse("""
            {
                "type": "mock"
            }""")

        scheduler = get_scheduler(inputDict)
        @test scheduler isa EnergyStorageScheduling.MockScheduler

        inputDict = JSON.parse("""
            {
                "type": "mock",
                "parameterOne": "",
                "parameterTwo": "",
                "sleepSeconds": 5.2
            }""")

        scheduler = get_scheduler(inputDict)
        @test scheduler isa EnergyStorageScheduling.MockScheduler
        @test scheduler.sleepSeconds == 5.2
    end

    @testset "OptScheduler" begin
        inputDict = JSON.parse("""
            {
                "type": "schedulerOptimization",
                "scheduleResolutionHrs": 1,
                "optWindowLenHrs":24,
                "intervalHrs": 24,
                "endSocPct": 50
            }""")

        scheduler = get_scheduler(inputDict)
        @test scheduler isa EnergyStorageScheduling.OptScheduler
        @test scheduler.resolution == Hour(1)
        @test scheduler.optWindow == 24
        @test scheduler.endSoc == (0.5, 0.5)
        @test scheduler.minNetLoadKw === nothing
        @test scheduler.powerLimitPu == 1.0

        inputDict = JSON.parse("""
            {
                "type": "schedulerOptimization",
                "scheduleResolutionHrs": 0.5,
                "optWindowLenHrs": 24.1,
                "intervalHrs": 2.6,
                "powerLimitPct": 84,
                "endSocPct": [45, 50],
                "minNetLoadKw": 0
            }""")

        scheduler = get_scheduler(inputDict)
        @test scheduler isa EnergyStorageScheduling.OptScheduler
        @test scheduler.resolution == Minute(30)
        @test scheduler.optWindow == 49
        @test scheduler.endSoc == (0.45, 0.5)
        @test scheduler.minNetLoadKw == 0.0
        @test scheduler.powerLimitPu == 0.84
    end
end

@testset "RTController Input" begin

    @testset "PIDController" begin
        ess = LiIonBattery(
            EnergyStorageSimulators.LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
            EnergyStorageSimulators.LiIonBatteryStates(0.5, 0)
        )

        inputDict = JSON.parse("""
            {
                "type": "pid",
                "resolutionSec": 5,
                "Kp": 8,
                "Ti": 0.3,
                "Td": 1
            }""")
        controller = get_rt_controller(inputDict, ess, UseCase[])
        @test controller isa EnergyStorageRTControl.PIDController
        @test controller.resolution == Second(5)
        @test controller.Kp == 8
        @test controller.Ti == 0.3
        @test controller.Td == 1

        inputDict = JSON.parse("""
            {
                "type": "pid",
                "resolutionSec": 0.1,
                "Kp": 8,
                "Ti": 0.3,
                "Td": 1
            }""")
        controller = get_rt_controller(inputDict, ess, UseCase[])
        @test controller isa EnergyStorageRTControl.PIDController
        @test controller.resolution == Millisecond(100)
    end

    @testset "AMAC" begin
        ess = LiIonBattery(
            EnergyStorageSimulators.LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
            EnergyStorageSimulators.LiIonBatteryStates(0.5, 0)
        )

        useCases = [
            VariabilityMitigation(
                FixedIntervalTimeSeries(
                    now(),
                    Minute(5),
                    [60.0, 110.6, 200.0, 90.0, 20.0, 92.4, 150.7]
                ),
                300
            )
        ]

        inputDict = JSON.parse("""
            {
                "type": "ama",
                "referenceSocPct":50,
                "maximumAllowableWindowSize": 2100,
                "maximumAllowableVariabilityPct":50,
                "referenceVariabilityPct": 10,
                "activationThresholdVariabilityPct": 2,
                "dampingParameter": 8
            }"""
        )
        controller = get_rt_controller(inputDict, ess, useCases)
        @test controller isa EnergyStorageRTControl.AMAController
        @test !controller.passive

        controller = get_rt_controller(inputDict, ess, UseCase[])
        @test controller isa EnergyStorageRTControl.AMAController
        @test controller.passive
    end
end
