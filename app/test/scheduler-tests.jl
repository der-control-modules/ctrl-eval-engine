
using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates
using CtrlEvalEngine.EnergyStorageUseCases: UseCase, EnergyArbitrage, Regulation, RegulationPricePoint
using CtrlEvalEngine.EnergyStorageScheduling: schedule, OptScheduler
using Dates

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
end