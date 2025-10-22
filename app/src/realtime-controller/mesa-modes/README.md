# MESA Control Modes

This directory contains implementations of control modes for MESA (Modular Energy Storage Architecture) controllers for Battery Energy Storage Systems (BESS), based on DNP3 Application Note 2018-001 and IEEE standards.

## Overview

MESA provides a modular, priority-based control architecture that enables flexible coordination of multiple control objectives. Each mode implements a specific control function and contributes to the overall system response based on its assigned priority.

### Architecture Principles

- **Priority-Based Control**: Modes execute in priority order (1 = highest)
- **Incremental Contribution**: Each mode adds its output to the cumulative result
- **Constraint Enforcement**: System limits are applied after all modes execute
- **Modular Design**: Modes can be easily added, removed, or reconfigured

## Mode Categories

### 🔴 Emergency Modes (Priority 1-2)
Critical grid support functions for emergency conditions.

### 🟡 Active Power Modes (Priority 3-8)
Primary energy management and grid services using active power.

### 🟢 Reactive Power Modes (Priority 5-10)
Voltage support and power quality services using reactive power.

---

## 🔴 Emergency Modes (`emergency-modes/`)

Emergency modes provide rapid response to critical grid conditions during ride-through events.

### Available Emergency Modes

| Mode | File | Purpose | Trigger |
|------|------|---------|---------|
| **Over-Frequency Emergency** | `over-frequency-emergency-mode.jl` | High Frequency Ride-Through | f > threshold |
| **Under-Frequency Emergency** | `under-frequency-emergency-mode.jl` | Low Frequency Ride-Through | f < threshold |
| **Over-Voltage Emergency** | `over-voltage-emergency-mode.jl` | High Voltage Ride-Through | V > threshold |
| **Under-Voltage Emergency** | `under-voltage-emergency-mode.jl` | Low Voltage Ride-Through | V < threshold |

### Common Emergency Mode Features

- **Proportional Response**: Power output proportional to deviation magnitude
- **SOC Protection**: Prevents over-charging/discharging during emergencies
- **Ramp Rate Control**: Smooth transitions to prevent grid disturbances
- **Maximum Power Limits**: Respects inverter and system capabilities

### Example: Frequency Emergency Configuration

```julia
# Under-frequency emergency (inject power when frequency drops)
ufem = UnderFrequencyEmergencyMode(
    MesaModeParams(1),           # Highest priority
    59.5,                        # Trigger at 59.5 Hz
    1000.0,                      # 1000 kW/Hz response
    5000.0,                      # 5 MW maximum
    RampParams(100.0, 100.0, 100.0, 100.0),  # Fast ramps
    80.0                         # Don't discharge above 80% SOC
)

# Over-frequency emergency (absorb power when frequency rises)
ofem = OverFrequencyEmergencyMode(
    MesaModeParams(1),           # Highest priority
    60.5,                        # Trigger at 60.5 Hz
    1000.0,                      # 1000 kW/Hz response
    5000.0,                      # 5 MW maximum
    RampParams(100.0, 100.0, 100.0, 100.0),  # Fast ramps
    20.0                         # Don't charge below 20% SOC
)
```

---

## 🟡 Active Power Modes (`active-power-modes/`)

Active power modes manage energy dispatch and provide grid services through real power control.

### Available Active Power Modes

| Mode | File | Purpose | Use Case |
|------|------|---------|----------|
| **Active Power Limit** | `active-power-limit-mode.jl` | Constrain power output | Inverter protection |
| **Active Power Smoothing** | `active-power-smoothing-mode.jl` | Smooth power variations | Renewable integration |
| **Active Response** | `active-response-mode.jl` | Demand response | Grid services |
| **AGC (Automatic Generation Control)** | `agc-mode.jl` | Frequency regulation | Grid balancing |
| **Charge/Discharge Storage** | `mesa-charge-discharge-storage-mode.jl` | Energy arbitrage | Economic dispatch |
| **Frequency-Watt** | `mesa-frequency-watt-mode.jl` | Frequency-based power control | Grid support |
| **Volt-Watt** | `mesa-volt-watt-mode.jl` | Voltage-based power control | Voltage regulation |

### Key Active Power Mode Features

#### Active Power Limit Mode
```julia
struct ActivePowerLimitMode <: MesaMode
    params::MesaModeParams
    maximumChargePercentage::Float64    # Max charging power (% of rating)
    maximumDischargePercentage::Float64 # Max discharging power (% of rating)
end
```
- Constrains power within specified percentage limits
- Acts as protection for other modes
- Simple percentage-based limiting

#### Charge/Discharge Storage Mode
```julia
struct ChargeDischargeStorageMode <: MesaMode
    params::MesaModeParams
    rampOrTimeConstant::Bool            # Use ramp rates vs time constants
    rampParams::RampParams              # Ramp rate configuration
    minimumReservePercent::Float64      # Minimum SOC reserve
    maximumReservePercent::Float64      # Maximum SOC reserve
    activePowerTarget::Union{Float64, Nothing}  # Power target (or use schedule)
end
```
- Follows scheduled power or fixed target
- Ramp rate limiting for smooth operation
- SOC-based energy reserves

#### Frequency-Watt Mode
```julia
struct FrequencyWattMode <: MesaMode
    params::MesaModeParams
    useCurves::Bool                     # Use curves vs linear gradients
    frequencyWattCurve::VertexCurve     # Primary frequency response curve
    lowHysteresisCurve::VertexCurve     # Low frequency hysteresis
    highHysteresisCurve::VertexCurve    # High frequency hysteresis
    startDelay::Dates.Millisecond       # Activation delay
    stopDelay::Dates.Millisecond        # Deactivation delay
    rampParams::RampParams              # Ramp rate limits
    minimumSoc::Float64                 # Minimum SOC for discharge
    maximumSoc::Float64                 # Maximum SOC for charge
    # ... additional parameters for gradient control
end
```
- Frequency-responsive power control
- Hysteresis curves to prevent oscillation
- Configurable delays and SOC limits

---

## 🟢 Reactive Power Modes (`reactive-power-modes/`)

Reactive power modes provide voltage support and power quality services through reactive power control.

### Available Reactive Power Modes

| Mode | File | Purpose | Use Case |
|------|------|---------|----------|
| **Volt-VAR** | `volt-var-mode.jl` | Voltage-dependent VAR control | Grid voltage regulation |
| **Power Factor** | `power-factor-mode.jl` | Maintain specified power factor | Utility compliance |
| **Reactive Power Limit** | `reactive-power-limit-mode.jl` | Constrain VAR output | Inverter protection |
| **Fixed VAR** | `fixed-var-mode.jl` | Constant reactive power | Grid support |
| **Watt-VAR** | `watt-var-mode.jl` | Power-dependent VAR control | Coordinated support |

### Key Reactive Power Mode Features

#### Volt-VAR Mode
```julia
struct VoltVARMode <: MesaMode
    params::MesaModeParams
    voltVarCurve::VertexCurve          # Voltage-to-VAR response curve
    referenceVoltageOffset::Float64     # Voltage reference offset
    filterTime::Dates.Second           # Voltage filtering time constant
    lowerDeadband::Float64             # Lower voltage deadband
    upperDeadband::Float64             # Upper voltage deadband
    minimumReactivePower::Float64      # Minimum VAR limit
    maximumReactivePower::Float64      # Maximum VAR limit
end
```
- Voltage-dependent reactive power response
- Configurable droop curves with deadbands
- Voltage filtering to prevent noise-induced oscillations

#### Power Factor Mode
```julia
struct PowerFactorMode <: MesaMode
    params::MesaModeParams
    targetPowerFactor::Float64         # Target PF (0.0 to 1.0)
    isLeading::Bool                    # Leading (true) or lagging (false)
    minimumActivePower::Float64        # Minimum P for PF control
    maximumReactivePower::Float64      # Maximum VAR capability
    minimumReactivePower::Float64      # Minimum VAR capability
end
```
- Maintains constant power factor
- Supports both leading and lagging operation
- Automatic Q calculation based on P

#### Watt-VAR Mode
```julia
struct WattVARMode <: MesaMode
    params::MesaModeParams
    wattVarCurve::VertexCurve          # Active power to VAR curve
    activePowerReference::Float64       # Reference power for normalization
    minimumActivePower::Float64         # Minimum P threshold
    maximumReactivePower::Float64       # Maximum VAR capability
    minimumReactivePower::Float64       # Minimum VAR capability
    hysteresisPercent::Float64         # Hysteresis band
end
```
- Coordinates reactive power with active power
- Hysteresis prevents rapid oscillations
- Useful for solar+storage applications

---

## Priority Coordination

### Recommended Priority Assignments

| Priority | Category | Example Modes |
|----------|----------|---------------|
| **1-2** | Emergency Response | Frequency/Voltage Emergency |
| **3-4** | Critical Active Power | AGC, Frequency-Watt |
| **5-6** | Primary Services | Volt-VAR, Power Factor, Charge/Discharge |
| **7-8** | Secondary Services | Watt-VAR, Active Response |
| **9-10** | Constraints/Limits | Power Limits, VAR Limits |

### Mode Interaction Guidelines

**Emergency + Regular Modes**:
- Emergency modes take absolute precedence
- Regular modes operate within emergency constraints
- SOC management prevents conflicting emergency responses

**Active + Reactive Power Coordination**:
- Consider apparent power limits: S = √(P² + Q²)
- Reactive power capability depends on active power level
- Prioritize based on system needs and utility requirements

**Multiple Modes of Same Type**:
- Higher priority modes set primary response
- Lower priority modes provide fine-tuning or constraints
- Avoid conflicting objectives at similar priorities

---

## Configuration Examples

### Example 1: Basic Grid Support Configuration

```julia
using Dates
using CtrlEvalEngine.EnergyStorageRTControl

modes = MesaMode[
    # Emergency response (highest priority)
    UnderFrequencyEmergencyMode(
        MesaModeParams(1), 59.5, 1000.0, 5000.0,
        RampParams(100.0, 100.0, 100.0, 100.0), 80.0
    ),
    
    # Primary voltage support
    VoltVARMode(
        MesaModeParams(5),
        VertexCurve([
            Vertex(-5.0, -1000.0), Vertex(0.0, 0.0), Vertex(5.0, 1000.0)
        ]),
        0.0, Second(5), 0.5, 0.5, -1200.0, 1200.0
    ),
    
    # Energy arbitrage
    ChargeDischargeStorageMode(
        MesaModeParams(6), true,
        RampParams(10.0, 10.0, 10.0, 10.0),
        10.0, 90.0, nothing
    ),
    
    # Protection limits
    ActivePowerLimitMode(
        MesaModeParams(9), 95.0, 95.0
    )
]

controller = MesaController(modes, Minute(5))
```

### Example 2: Utility Compliance Configuration

```julia
modes = MesaMode[
    # Frequency regulation
    FrequencyWattMode(
        MesaModeParams(3), false, 
        VertexCurve([]), VertexCurve([]), VertexCurve([]),
        Millisecond(100), Millisecond(100),
        RampParams(20.0, 20.0, 20.0, 20.0),
        20.0, 80.0, true, false,
        60.1, 59.9, 60.0, 60.0,
        100.0, 100.0, 100.0, 100.0, 50.0, 50.0
    ),
    
    # Required power factor
    PowerFactorMode(
        MesaModeParams(5), 0.95, false, 50.0, 1000.0, -1000.0
    ),
    
    # Reactive power limits
    ReactivePowerLimitMode(
        MesaModeParams(10), 90.0, -90.0, 1200.0
    )
]

controller = MesaController(modes, Second(30))
```

---

## Implementation Status

### ✅ Fully Implemented

**Emergency Modes**:
- All 4 emergency modes with comprehensive documentation
- SOC-aware operation and ramp rate control
- DNP3 AN-2018-001 compliance

**Reactive Power Modes**:
- All 5 reactive power modes with curve utilities
- Example configurations and usage patterns
- Comprehensive documentation and testing guidelines

### 🚧 Partially Implemented

**Active Power Modes**:
- Core mode structures implemented
- Some modes have placeholder TODO comments
- Need comprehensive documentation and examples

### 🔄 Integration Requirements

**Measurement Systems**:
- Frequency measurement: `get_frequency_measurement(controller, t)`
- Voltage measurement: `get_voltage_measurement(controller, t)`
- Power measurement: Real-time P/Q measurements

**Curve Evaluation**:
- ✅ `evaluate_curve()` - Linear interpolation
- ✅ `evaluate_curve_with_hysteresis()` - Anti-chatter control
- ✅ `create_symmetric_curve()` - Symmetric curve generation
- ✅ `validate_curve()` - Curve validation

**Advanced Features** (Future):
- Dead-band support for emergency modes
- Time-dependent ride-through curves
- Adaptive curve parameters
- Machine learning-based optimization

---

## File Structure

```
mesa-modes/
├── README.md                           # This file
├── active-power-modes/
│   ├── active-power-limit-mode.jl
│   ├── active-power-smoothing-mode.jl
│   ├── active-response-mode.jl
│   ├── agc-mode.jl
│   ├── mesa-charge-discharge-storage-mode.jl
│   ├── mesa-frequency-watt-mode.jl
│   └── mesa-volt-watt-mode.jl
├── emergency-modes/
│   ├── over-frequency-emergency-mode.jl
│   ├── under-frequency-emergency-mode.jl
│   ├── over-voltage-emergency-mode.jl
│   ├── under-voltage-emergency-mode.jl
│   ├── README.md                       # Emergency modes documentation
│   └── UPDATE_SUMMARY.md              # Emergency modes update details
└── reactive-power-modes/
    ├── volt-var-mode.jl
    ├── power-factor-mode.jl
    ├── reactive-power-limit-mode.jl
    ├── fixed-var-mode.jl
    ├── watt-var-mode.jl
    ├── curve-utils.jl                  # Curve evaluation utilities
    ├── examples.jl                     # Usage examples
    ├── README.md                       # Reactive power documentation
    ├── IMPLEMENTATION_SUMMARY.md       # Implementation details
    └── QUICK_REFERENCE.md             # Quick reference guide
```

---

## Testing and Validation

### Unit Testing Strategy

**Individual Mode Tests**:
- Parameter validation
- Control logic verification
- Limit enforcement
- Edge case handling

**Curve Evaluation Tests**:
- Linear interpolation accuracy
- Hysteresis behavior
- Boundary condition handling
- Invalid curve detection

### Integration Testing

**Multi-Mode Coordination**:
- Priority ordering verification
- Mode interaction validation
- Constraint propagation
- Performance under load

**System-Level Testing**:
- End-to-end control scenarios
- Grid disturbance response
- Long-term stability
- Standards compliance verification

### Test File Locations

```julia
# Unit tests
app/test/mesa-controller-tests.jl        # Controller framework tests
app/test/controller-tests.jl             # Individual mode tests

# Integration tests (to be created)
app/test/emergency-mode-tests.jl         # Emergency mode scenarios
app/test/reactive-power-mode-tests.jl    # Reactive power scenarios
app/test/multi-mode-coordination-tests.jl # Multi-mode interactions
```

---

## Standards Compliance

### Primary Standards

- **DNP3 AN-2018-001**: "DNP3 Application Note for Distributed Energy Resources (DER)"
- **IEEE 1547-2018**: "Standard for Interconnection and Interoperability of DER"
- **IEEE 2800-2022**: "Standard for Interconnection and Interoperability of IBR"

### Compliance Features

**Grid Support Functions**:
- ✅ Frequency ride-through (emergency modes)
- ✅ Voltage ride-through (emergency modes)
- ✅ Voltage regulation (Volt-VAR mode)
- ✅ Power factor control (Power Factor mode)
- ✅ Active power control (various active power modes)

**Protection and Safety**:
- ✅ Ramp rate limiting
- ✅ SOC-based constraints
- ✅ Power limit enforcement
- ✅ Energy limit checking
- ✅ Apparent power awareness

**Interoperability**:
- ✅ Modular architecture
- ✅ Configurable parameters
- ✅ Priority-based coordination
- ✅ Standard data types and units

---

## Getting Started

### 1. Basic Setup

```julia
using Dates
using CtrlEvalEngine.EnergyStorageRTControl

# Create a simple controller with one mode
mode = ActivePowerLimitMode(
    MesaModeParams(5),  # Priority 5
    95.0,               # 95% max charge
    95.0                # 95% max discharge
)

controller = MesaController([mode], Minute(5))
```

### 2. Add Emergency Response

```julia
# Add emergency modes (highest priority)
emergency_modes = [
    UnderFrequencyEmergencyMode(
        MesaModeParams(1), 59.5, 1000.0, 5000.0,
        RampParams(100.0, 100.0, 100.0, 100.0), 80.0
    ),
    OverFrequencyEmergencyMode(
        MesaModeParams(1), 60.5, 1000.0, 5000.0,
        RampParams(100.0, 100.0, 100.0, 100.0), 20.0
    )
]

controller = MesaController(vcat(emergency_modes, [mode]), Minute(5))
```

### 3. Add Reactive Power Support

```julia
# Add voltage support
volt_var = VoltVARMode(
    MesaModeParams(5),
    VertexCurve([
        Vertex(-2.0, -500.0), Vertex(-1.0, 0.0),
        Vertex(1.0, 0.0), Vertex(2.0, 500.0)
    ]),
    0.0, Second(5), 0.5, 0.5, -1200.0, 1200.0
)

all_modes = vcat(emergency_modes, [mode, volt_var])
controller = MesaController(all_modes, Minute(5))
```

### 4. Control Execution

```julia
# Execute control (typically called from main control loop)
result = control(ess, controller, schedulePeriod, useCases, t, spProgress)
```

---

## Contributing

### Adding New Modes

1. **Create mode struct** inheriting from `MesaMode`
2. **Implement `modecontrol()` function** with required signature
3. **Add comprehensive docstrings** explaining purpose and parameters
4. **Add to appropriate subdirectory** (active-power, emergency, reactive-power)
5. **Update `mesa.jl`** include section
6. **Create unit tests** in `app/test/`
7. **Update this README** with mode documentation

### Mode Development Template

```julia
"""
    NewMode

Brief description of what this mode does.

# Parameters
- `param1`: Description of parameter 1
- `param2`: Description of parameter 2
"""
struct NewMode <: MesaMode
    params::MesaModeParams
    param1::Float64
    param2::Bool
end

function modecontrol(
    mode::NewMode,
    ess::EnergyStorageSystem,
    controller::MesaController,
    schedulePeriod::SchedulePeriod,
    useCases::AbstractVector{<:UseCase},
    t::Dates.DateTime,
    spProgress::VariableIntervalTimeSeries,
    currentIterationPower::Float64
)
    # Implement control logic here
    return adjustment_power
end
```

### Documentation Standards

- **Comprehensive docstrings** for all structs and functions
- **Parameter descriptions** with units and typical ranges
- **Usage examples** showing common configurations
- **Integration notes** for measurement requirements
- **Standards references** where applicable

### Testing Requirements

- **Unit tests** for individual mode logic
- **Integration tests** with other modes
- **Edge case coverage** (zero power, SOC limits, etc.)
- **Performance tests** for real-time requirements
- **Standards compliance tests** where applicable

---

## Support and References

### Documentation

- **Emergency Modes**: `emergency-modes/README.md`
- **Reactive Power Modes**: `reactive-power-modes/README.md`
- **Quick Reference**: `reactive-power-modes/QUICK_REFERENCE.md`
- **Examples**: `reactive-power-modes/examples.jl`

### Standards and References

- [DNP3 Technical Bulletins](https://www.dnp.org/)
- [IEEE 1547 Standards](https://standards.ieee.org/)
- [NERC Standards](https://www.nerc.com/) (North America)
- [IEC 61850](https://www.iec.ch/) (International)

### Project Resources

- **Main README**: `../../README.md`
- **Installation Guide**: `../../README.md#installation`
- **Test Visualization**: `app/test/visualize_results.jl`
- **Example Configurations**: Various `examples.jl` files

---

*This README provides a comprehensive overview of all MESA control modes. For detailed information on specific mode categories, refer to the individual README files in each subdirectory.*