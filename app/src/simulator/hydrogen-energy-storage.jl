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

struct HydrogenEnergyStorageSpecs
    electrolyzerSpecs::ElectrolyzerSpecs
    hydrogenStorageSpecs::HydrogenStorageSpecs
    fuelCellSpecs::FuelCellSpecs
end

mutable struct HydrogenEnergyStorageStates
    lowPressureH2Kg::Float64
    mediumPressureH2Kg::Float64
    electrolyzerOn::Bool
    fuelCellOn::Bool
    compressorOn::Bool
end

struct HydrogenEnergyStorageSystem <: EnergyStorageSystem
    specs::HydrogenEnergyStorageSpecs
    states::HydrogenEnergyStorageStates
end

function _operate!(
    hess::HydrogenEnergyStorageSystem,
    powerKw::Real,
    durationHour::Real,
    _::Real,
)
    if powerKw > 0
        h2_needed = powerKw * durationHour / (hess.specs.fuelCellSpecs.efficiencyPu * 39.4)
        
        h2_from_lp = min(h2_needed, hess.states.lowPressureH2Kg)
        hess.states.lowPressureH2Kg -= h2_from_lp
        
        if h2_from_lp < h2_needed
            h2_from_mp = min(
                h2_needed - h2_from_lp,
                hess.states.mediumPressureH2Kg
            )
            hess.states.mediumPressureH2Kg -= h2_from_mp
        end
        
        hess.states.fuelCellOn = true
        hess.states.electrolyzerOn = false
        hess.states.compressorOn = false
    else
        h2_produced = -powerKw * durationHour / hess.specs.electrolyzerSpecs.ratePowerKw
    
        space_in_lp = hess.specs.hydrogenStorageSpecs.lowPressureTankSizeKg - 
                     hess.states.lowPressureH2Kg
        h2_to_lp = min(h2_produced, space_in_lp)
        hess.states.lowPressureH2Kg += h2_to_lp
        
        if h2_to_lp < h2_produced
            h2_to_mp = min(
                h2_produced - h2_to_lp,
                hess.specs.hydrogenStorageSpecs.mediumPressureTankSizeKg - 
                hess.states.mediumPressureH2Kg
            )
            hess.states.mediumPressureH2Kg += h2_to_mp
            hess.states.compressorOn = true
        else
            hess.states.compressorOn = false
        end
        
        hess.states.electrolyzerOn = true
        hess.states.fuelCellOn = false
    end
end

function SOC(hess::HydrogenEnergyStorageSystem)
    total_h2 = hess.states.lowPressureH2Kg + hess.states.mediumPressureH2Kg
    total_capacity = hess.specs.hydrogenStorageSpecs.lowPressureTankSizeKg +
                    hess.specs.hydrogenStorageSpecs.mediumPressureTankSizeKg
    return total_h2 / total_capacity
end

function energy_state(hess::HydrogenEnergyStorageSystem)
    total_h2 = hess.states.lowPressureH2Kg + hess.states.mediumPressureH2Kg
    return total_h2 * 39.4 * hess.specs.fuelCellSpecs.efficiencyPu 
end

function p_max(hess::HydrogenEnergyStorageSystem, durationHour::Real, _::Real)
    total_h2 = hess.states.lowPressureH2Kg + hess.states.mediumPressureH2Kg
    available_energy = total_h2 * 39.4 * hess.specs.fuelCellSpecs.efficiencyPu
    return min(
        hess.specs.fuelCellSpecs.ratedPowerKw,
        available_energy / durationHour
    )
end

function p_max(hess::HydrogenEnergyStorageSystem)
    return hess.specs.fuelCellSpecs.ratedPowerKw
end

function p_min(hess::HydrogenEnergyStorageSystem, durationHour::Real, _::Real)
    remaining_capacity = (
        hess.specs.hydrogenStorageSpecs.lowPressureTankSizeKg - hess.states.lowPressureH2Kg +
        hess.specs.hydrogenStorageSpecs.mediumPressureTankSizeKg - hess.states.mediumPressureH2Kg
    )
    max_h2_intake = remaining_capacity / durationHour
    return max(
        -hess.specs.electrolyzerSpecs.ratePowerKw,
        -max_h2_intake * hess.specs.electrolyzerSpecs.ratePowerKw
    )
end

function p_min(hess::HydrogenEnergyStorageSystem)
    return -hess.specs.electrolyzerSpecs.ratePowerKw
end

function e_max(hess::HydrogenEnergyStorageSystem)
    total_capacity = (
        hess.specs.hydrogenStorageSpecs.lowPressureTankSizeKg +
        hess.specs.hydrogenStorageSpecs.mediumPressureTankSizeKg
    )
    return total_capacity * 39.4 * hess.specs.fuelCellSpecs.efficiencyPu
end

function e_min(::HydrogenEnergyStorageSystem)
    return 0.0
end

function ηRT(hess::HydrogenEnergyStorageSystem)
    return hess.specs.fuelCellSpecs.efficiencyPu
end

