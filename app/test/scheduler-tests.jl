
using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates, p_max
using CtrlEvalEngine.EnergyStorageUseCases: UseCase, EnergyArbitrage, Regulation, RegulationPricePoint
using CtrlEvalEngine.EnergyStorageScheduling: schedule, OptScheduler, ManualScheduler, RLScheduler
using Dates


@testset "ML Scheduler" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )

    rlScheduler = RLScheduler(Hour(1), "Q-learning", 4000)
    tStart = floor(now(), Hour(1))
    useCases = UseCase[
        EnergyArbitrage(
            VariableIntervalTimeSeries(
                range(tStart; step=Hour(1), length=5),
                [10, 20, 1, 10]
            )
        )
    ]
    sVar = schedule(ess, rlScheduler, useCases, tStart)
    @test length(sVar.powerKw) == 4
end
