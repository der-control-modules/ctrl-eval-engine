
struct HydrogenEnergyStorageSystem <: EnergyStorageSystem
    specs::HydrogenEnergyStorageSpecs
    states::HydrogenEnergyStorageStates
end

struct HydrogenEnergyStorageSpecs
    electrolyzerSpecs::ElectrolyzerSpecs
    hydrogenStorageSpecs::HydrogenStorageSpecs
    fuelCellSpecs::FuelCellSpecs
end

struct ElectrolyzerSpecs
    ratePowerKw::Float64
end

struct HydrogenStorageSpecs
    lowPressureTankSizeKg::Float64
    mediumPressureTankSizeKg::Float64
end

struct FuelCellSpecs
    ratedPowerKw::Float64
    efficiencyPu::Float64
    minLoadingPu::Float64
    operatingLifetimeHour::Float64
end

mutable struct HydrogenEnergyStorageStates
    lowPressureH2Kg::Float64
    mediumPressureH2Kg::Float64
    electrolyzerOn::Bool
    fuelCellOn::Bool
    compressorOn::Bool
end

function _operate!(
    hess::HydrogenEnergyStorageSystem,
    powerKw::Real,
    durationHour::Real,
    ::Real,
)
    # If `powerkW` is positive, use fuel cell to generate electricity (discharging)
    #     use H2 from low-pressure tank first, only withdraw from medium-pressure tank if low-pressure is empty
    # else (`powerkW < 0` charging)
    #     use electrolyzer to produce hydrogen
    #     charge low-pressure tank first, only compress and charge medium-pressure tank if low-pressure tank is full
    #         if compressor is started, reduce electrolyer power to make sure the total power consumption matches `-powerkW`
end

# TODO: implement all exported functions
