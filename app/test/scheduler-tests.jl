
using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates
using CtrlEvalEngine.EnergyStorageUseCases: UseCase, EnergyArbitrage, Regulation, RegulationPricePoint
using CtrlEvalEngine.EnergyStorageScheduling: schedule, OptScheduler, ManualScheduler
using Dates

@testset "Manual Scheduler" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    manSched = ManualScheduler([3.6, 65.2, 87.9, 2.4, 91.7], floor(now(), Hour(1)), Hour(1))
    sched = schedule(ess, manSched, Nothing, floor(now(), Hour(1)))
    @test sched.powerKw == [3.6, 65.2, 87.9, 2.4, 91.7]
    @test sched.tStart == floor(now(), Hour(1))
    @test sched.resolution == Hour(1)
end

@testset "Optimization Scheduler" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    optScheduler = OptScheduler(Hour(1), Hour(4), 4)
    tStart = floor(now(), Hour(1))
    useCases = UseCase[
        EnergyArbitrage(
            VariableIntervalTimeSeries(
                range(tStart; step=Hour(1), length=5),
                [10, 20, 1, 10]
            )
        )
    ]
    sVar = schedule(ess, optScheduler, useCases, tStart)
    @test sVar.powerKw[2] > sVar.powerKw[3]

    useCases = UseCase[
        EnergyArbitrage(
            FixedIntervalTimeSeries(
                tStart, Hour(1), [10, 20, 1, 10]
            )
        )
    ]
    sFix = schedule(ess, optScheduler, useCases, tStart)
    @test all(sVar.powerKw .== sFix.powerKw)

    # OptScheduler with regulation
    useCases = UseCase[
        EnergyArbitrage(
            FixedIntervalTimeSeries(
                tStart, Hour(1), [10, 20, 1, 10]
            )
        ),
        Regulation(
            FixedIntervalTimeSeries(
                tStart,
                Hour(1),
                [
                    RegulationPricePoint(5.3, 3),
                    RegulationPricePoint(20.1, 4),
                    RegulationPricePoint(12, 2),
                    RegulationPricePoint(10, 3.6)
                ]
            ),
            1.0
        )
    ]
    sReg = schedule(ess, optScheduler, useCases, tStart)
    @test length(sReg.powerKw) == 4

    optScheduler2 = OptScheduler(Hour(1), Hour(4), 4; powerLimitPu=0.5, minNetLoadKw=-100)
    s2 = schedule(ess, optScheduler2, useCases, tStart)
    @test all(abs.(s2.powerKw) .≤ p_max(ess.specs) * 0.5)
    @test all(s2.powerKw .≤ 100)
end