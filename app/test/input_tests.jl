
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
                "type": "optimization",
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
                "type": "optimization",
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
        inputDict = JSON.parse("""
            {
                "type": "pid",
                "resolutionSec": 5,
                "Kp": 8,
                "Ti": 0.3,
                "Td": 1
            }""")
        controller = get_rt_controller(inputDict)
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
        controller = get_rt_controller(inputDict)
        @test controller isa EnergyStorageRTControl.PIDController
        @test controller.resolution == Millisecond(100)
    end
end

@testset "Use Case Input" begin
    inputDict = JSON.parse("""
        {
            "Variability Mitigation": {
                "pvGenProfile": [
                    {
                        "DateTime": "2018-01-21T00:00",
                        "Power": 351.54
                    },
                    {
                        "DateTime": "2018-01-21T00:01",
                        "Power": 351.5
                    },
                    {
                        "DateTime": "2018-01-21T00:02",
                        "Power": 35.54
                    },
                    {
                        "DateTime": "2018-01-21T00:03",
                        "Power": 51.54
                    }
                ],
                "ratedPowerKw": 500
            }
        }"""
    )
    useCases = get_use_cases(inputDict)
    @test useCases <: AbstractVector{<:UseCase}
    @test useCases[1] isa VariabilityMitigation
    @test useCases[1].pvGenProfile.resolution == Minute(1)
    @test useCases[1].ratedPowerKw == 500
end