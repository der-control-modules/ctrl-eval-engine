
include("../simulator/main.jl")
include("../use-case/main.jl")
include("../scheduler/main.jl")

using .EnergyStorageSimulators: LiIonBattery, LFP_LiIonBatterySpecs, LiIonBatteryStates
using .EnergyStorageUseCases: EnergyArbitrage, EnergyPrice
using .EnergyStorageScheduling: schedule, OptScheduler
using Dates

@testset "Optimization Scheduler" begin
    ess = LiIonBattery(
        LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
        LiIonBatteryStates(0.5, 0)
    )
    optScheduler = OptScheduler(Hour(1), Hour(24), 24)
    tStart = floor(now(), Hour(1))
    useCases = [EnergyArbitrage(EnergyPrice(range(tStart; step=Hour(1), length=24), rand(24) .* 10))]
    schedule(ess, optScheduler, useCases, tStart)
end