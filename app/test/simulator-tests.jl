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

    @testset "Hydrogen Energy Storage System" begin
        ess = HydrogenEnergyStorageSystem(
            EnergyStorageSimulators.HydrogenEnergyStorageSpecs(
                EnergyStorageSimulators.ElectrolyzerSpecs(10.0),
                EnergyStorageSimulators.HydrogenStorageSpecs(50.0, 500.0),
                EnergyStorageSimulators.FuelCellSpecs(5.0, 0.6, 0.3, 40000.0)
            ),
            EnergyStorageSimulators.HydrogenEnergyStorageStates(25.0, 250.0, false, false, false)
        )

        @test SOC(ess) == 0.5
        @test SOH(ess) == 1
        @test p_max(ess) == 5
        @test p_min(ess) == -10
        @test e_max(ess) ≈ 550 * 39.4 * 0.6
        @test e_min(ess) == 0
        @test energy_state(ess) ≈ 275 * 39.4 * 0.6
        @test ηRT(ess) == 0.6

        operate!(ess, 2)
        @test SOC(ess) < 0.5
        soc1 = SOC(ess)

        operate!(ess, -2)
        @test SOC(ess) > soc1
        soc2 = SOC(ess)

        operate!(ess, -4, Minute(5))
        @test SOC(ess) > soc2
    end

    @testset "HESS Low Pressure to Medium Pressure" begin
        ess = HydrogenEnergyStorageSystem(
            EnergyStorageSimulators.HydrogenEnergyStorageSpecs(
                EnergyStorageSimulators.ElectrolyzerSpecs(10.0, 50.0, 0.1),
                EnergyStorageSimulators.HydrogenStorageSpecs(50.0, 500.0, 0.1, 0.9, 0.5, 5.0),
                EnergyStorageSimulators.FuelCellSpecs(5.0, 0.6, 0.3, 40000.0)
            ),
            EnergyStorageSimulators.HydrogenEnergyStorageStates(45.0, 250.0, false, false, false)
        )
        
        operate!(ess, -8.0, Hour(1))
        
        @test ess.states.lowPressureH2Kg ≈ 50.0
        @test ess.states.mediumPressureH2Kg > 250.0
        @test ess.states.electrolyzerOn == true
        @test ess.states.compressorOn == true
    end
end
