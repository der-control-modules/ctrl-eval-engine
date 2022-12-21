"""
    EnergyStorageSimulators

The `EnergyStorageSimulators` provides type and functions for simulating the operation and behaviors of energy storage systems.
"""
module EnergyStorageSimulators

using Dates

export EnergyStorageSystem, MockSimulator, operate!, get_ess, SOC

abstract type EnergyStorageSystem end

include("mock-simulator.jl")

function get_ess(inputDict)
    return MockSimulator(
        MockES_Specs(1.0, 2.0, 0.9),
        MockES_States(0.5)
    )
end

end