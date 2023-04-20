
using CtrlEvalEngine.EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates
using CtrlEvalEngine.EnergyStorageUseCases: EnergyArbitrage
using CtrlEvalEngine.EnergyStorageScheduling: schedule, OptScheduler
using Dates

@testset "Optimization Scheduler" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    optScheduler = OptScheduler(Hour(1), Hour(4), 4)
    tStart = floor(now(), Hour(1))
    useCases = [
        EnergyArbitrage(
            CtrlEvalEngine.VariableIntervalTimeSeries(
                range(tStart; step=Hour(1), length=5),
                [10, 20, 1, 10]
            )
        )
    ]
    sVar = schedule(ess, optScheduler, useCases, tStart)
    @test sVar.powerKw[2] > sVar.powerKw[3]

    useCases = [
        EnergyArbitrage(
            CtrlEvalEngine.FixedIntervalTimeSeries(
                tStart, Hour(1), [10, 20, 1, 10]
            )
        )
    ]
    sFix = schedule(ess, optScheduler, useCases, tStart)
    @test all(sVar.powerKw .== sFix.powerKw)
end