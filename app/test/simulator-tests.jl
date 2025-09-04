
using CtrlEvalEngine.EnergyStorageSimulators
using Dates

@testset "Simulators" begin
    @testset "Mock Simulator" begin
        ess = MockSimulator(
            EnergyStorageSimulators.MockES_Specs(500, 1000, 0.9),
            EnergyStorageSimulators.MockES_States(0.5)
        )

        @test SOC(ess) == 0.5
        @test SOH(ess) == 1
        @test p_max(ess) == 500
        @test p_min(ess) == -500
        @test e_max(ess) == 1000
        @test e_min(ess) == 0
        @test energy_state(ess) == 500
        @test ηRT(ess) == 0.81

        operate!(ess, 100)
        @test SOC(ess) < 0.5
        soc1 = SOC(ess)

        operate!(ess, -100)
        @test SOC(ess) > soc1
        soc2 = SOC(ess)

        operate!(ess, -200, Minute(5))
        @test SOC(ess) > soc2
    end
    @testset "LiIon Battery Simulator" begin
        ess = LiIonBattery(
            EnergyStorageSimulators.LFP_LiIonBatterySpecs(500, 1000, 0.85, 2000),
            EnergyStorageSimulators.LiIonBatteryStates(0.5, 0)
        )
        @test SOC(ess) == 0.5
        @test SOH(ess) == 1
        @test p_max(ess) == 500
        @test p_min(ess) == -500
        @test e_max(ess) == 1000
        @test e_min(ess) == 0
        @test energy_state(ess) == 500
        @test ηRT(ess) == 0.85

        operate!(ess, 100)
        @test SOC(ess) < 0.5
        soc1 = SOC(ess)

        operate!(ess, -100)
        @test SOC(ess) > soc1
        soc2 = SOC(ess)

        operate!(ess, -200, Minute(5))
        @test SOC(ess) > soc2
        
        @test SOH(ess) < 1
    end
end