struct ElectrolyzerSpecs
    ratedPowerKw::Float64
    electricityPowerKwhPerKg::Float64
    minLoadPu::Float64
end

struct HydrogenStorageSpecs
    lowPressureTankSizeKg::Float64
    mediumPressureTankSizeKg::Float64
    compressionLossPu::Float64
    compressorKwhPerKg::Float64
    compressorRatedPowerKw::Float64
end

struct FuelCellSpecs
    ratedPowerKw::Float64
    efficiencyPu::Float64
    minLoadingPu::Float64
    operatingLifetimeHour::Float64
end

struct WaterCostSpecs
    waterCostChargeRateDollarsPerKgal::Float64
    waterCostDrainageChargeRateDollarsPerKgal::Float64
    waterCostMinimumChargeDollars::Float64
    waterCostThresholdKgal::Float64
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

const H2_KWH_PER_KG = 39.39

function _operate!(
    hess::HydrogenEnergyStorageSystem,
    powerKw::Real,
    durationHour::Real,
    _::Real,
)
    if powerKw > 0
        h2_needed = powerKw * durationHour / (hess.specs.fuelCellSpecs.efficiencyPu * H2_KWH_PER_KG)
        
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
        h2_produced = (-powerKw * durationHour) / hess.specs.electrolyzerSpecs.electricityPowerKwhPerKg
    
        space_in_lp = hess.specs.hydrogenStorageSpecs.lowPressureTankSizeKg - 
                     hess.states.lowPressureH2Kg
        h2_to_lp = min(h2_produced, space_in_lp)
        hess.states.lowPressureH2Kg += h2_to_lp

        if h2_to_lp < h2_produced
            time_to_fill_lp = (hess.specs.electrolyzerSpecs.electricityPowerKwhPerKg * h2_to_lp) / -powerKw

            remaining_duration = durationHour - time_to_fill_lp

            hp = ((-powerKw * durationHour) / hess.specs.hydrogenStorageSpecs.compressorKwhPerKg) / (1 + (hess.specs.electrolyzerSpecs.electricityPowerKwhPerKg / hess.specs.hydrogenStorageSpecs.compressorKwhPerKg))

            hm = hp * (1 - hess.specs.hydrogenStorageSpecs.compressionLossPu)

            hess.states.mediumPressureH2Kg += hm
            hess.states.compressorOn = true
        else
            hess.states.compressorOn = false
        end
        
        if h2_produced > 0
            hess.states.electrolyzerOn = true
        end

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
    return total_h2 * H2_KWH_PER_KG * hess.specs.fuelCellSpecs.efficiencyPu 
end

function p_max(hess::HydrogenEnergyStorageSystem, durationHour::Real, _::Real)
    total_h2 = hess.states.lowPressureH2Kg + hess.states.mediumPressureH2Kg
    available_energy = total_h2 * H2_KWH_PER_KG * hess.specs.fuelCellSpecs.efficiencyPu
    max_power = min(
        hess.specs.fuelCellSpecs.ratedPowerKw,
        available_energy / durationHour
    )
    
    return max_power < (hess.specs.fuelCellSpecs.minLoadingPu * hess.specs.fuelCellSpecs.ratedPowerKw) ? 
        0.0 : max_power
end

function p_max(hess::HydrogenEnergyStorageSystem)
    return hess.specs.fuelCellSpecs.ratedPowerKw
end

# TODO: change
function p_min(hess::HydrogenEnergyStorageSystem, durationHour::Real, _::Real)
    remaining_capacity = (
        hess.specs.hydrogenStorageSpecs.lowPressureTankSizeKg - hess.states.lowPressureH2Kg +
        hess.specs.hydrogenStorageSpecs.mediumPressureTankSizeKg - hess.states.mediumPressureH2Kg
    )

    hlp = hess.specs.hydrogenStorageSpecs.lowPressureTankSizeKg - hess.states.lowPressureH2Kg
    
    hm = hess.specs.hydrogenStorageSpecs.mediumPressureTankSizeKg - hess.states.mediumPressureH2Kg

    hc = hm / (1 - hess.specs.hydrogenStorageSpecs.compressionLossPu)

    he = hlp + hc

    pe = (he * hess.specs.electrolyzerSpecs.electricityPowerKwhPerKg) / durationHour

    pc = (hc * hess.specs.hydrogenStorageSpecs.compressorKwhPerKg) / durationHour

    p = pe + pc

    min_power = -min(p, hess.specs.electrolyzerSpecs.ratedPowerKw)

    return abs(min_power) < (hess.specs.electrolyzerSpecs.minLoadPu * hess.specs.electrolyzerSpecs.ratedPowerKw) ?
        0.0 : min_power
end

function p_min(hess::HydrogenEnergyStorageSystem)
    return -hess.specs.electrolyzerSpecs.ratedPowerKw
end

function e_max(hess::HydrogenEnergyStorageSystem)
    total_capacity = (
        hess.specs.hydrogenStorageSpecs.lowPressureTankSizeKg +
        hess.specs.hydrogenStorageSpecs.mediumPressureTankSizeKg
    )
    return total_capacity * H2_KWH_PER_KG * hess.specs.fuelCellSpecs.efficiencyPu
end

function e_min(::HydrogenEnergyStorageSystem)
    return 0.0
end

function ηRT(hess::HydrogenEnergyStorageSystem)
    return hess.specs.fuelCellSpecs.efficiencyPu * H2_KWH_PER_KG / hess.specs.electrolyzerSpecs.electricityPowerKwhPerKg
end

function self_discharge_rate(::HydrogenEnergyStorageSystem)
    return 0.0
end
