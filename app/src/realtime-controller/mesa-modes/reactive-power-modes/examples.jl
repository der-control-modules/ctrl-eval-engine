"""
Example configurations for MESA reactive power control modes.

This file demonstrates how to configure and use each reactive power mode
for common use cases in BESS applications.
"""

using Dates
using CtrlEvalEngine.EnergyStorageRTControl

# =============================================================================
# Example 1: Volt-VAR Mode for Grid Voltage Support
# =============================================================================

"""
Create a typical Volt-VAR mode for voltage regulation.
This example uses a standard droop curve where:
- High voltage (>122V) requires absorbing VARs (negative)
- Low voltage (<118V) requires injecting VARs (positive)
- Deadband around nominal (118-122V) for stability
"""
function example_volt_var_mode()
    # Define voltage-VAR curve
    # Format: Vertex(voltage_deviation, reactive_power)
    volt_var_curve = VertexCurve([
        Vertex(-10.0, -1000.0),  # Very low voltage: inject max VARs
        Vertex(-2.0, -500.0),    # Low voltage: inject VARs
        Vertex(-1.0, 0.0),       # Lower deadband edge
        Vertex(1.0, 0.0),        # Upper deadband edge
        Vertex(2.0, 500.0),      # High voltage: absorb VARs
        Vertex(10.0, 1000.0)     # Very high voltage: absorb max VARs
    ])
    
    mode = VoltVARMode(
        MesaModeParams(priority=5),  # Medium priority
        volt_var_curve,
        referenceVoltageOffset=0.0,   # No offset from nominal
        filterTime=Second(5),          # 5 second voltage filter
        lowerDeadband=1.0,            # 1V lower deadband
        upperDeadband=1.0,            # 1V upper deadband
        minimumReactivePower=-1200.0, # Max absorption (VARs)
        maximumReactivePower=1200.0   # Max injection (VARs)
    )
    
    return mode
end

# =============================================================================
# Example 2: Power Factor Mode for Utility Compliance
# =============================================================================

"""
Create a power factor mode to maintain 0.95 lagging power factor.
Common requirement for utility interconnection agreements.
"""
function example_power_factor_mode()
    mode = PowerFactorMode(
        MesaModeParams(priority=6),  # Medium priority
        targetPowerFactor=0.95,       # 0.95 PF
        isLeading=false,              # Lagging (inductive)
        minimumActivePower=50.0,      # Only apply above 50 kW
        maximumReactivePower=1000.0,  # Max capability (VARs)
        minimumReactivePower=-1000.0  # Min capability (VARs)
    )
    
    return mode
end

"""
Create a unity power factor mode (no reactive power).
Useful for pure energy arbitrage applications.
"""
function example_unity_power_factor_mode()
    mode = PowerFactorMode(
        MesaModeParams(priority=6),
        targetPowerFactor=1.0,        # Unity PF
        isLeading=false,              # Direction doesn't matter at unity
        minimumActivePower=0.0,       # Always apply
        maximumReactivePower=0.0,     # No reactive power
        minimumReactivePower=0.0      # No reactive power
    )
    
    return mode
end

# =============================================================================
# Example 3: Fixed VAR Mode for Constant Support
# =============================================================================

"""
Create a fixed VAR mode to provide constant capacitive support.
Useful for areas with chronic low voltage issues.
"""
function example_fixed_var_mode()
    mode = FixedVARMode(
        MesaModeParams(priority=7),
        targetReactivePower=500.0,    # Constant 500 VAR injection
        useRampRate=true,             # Enable smooth transitions
        rampParams=RampParams(         # Configure ramp rates
            10.0,  # dischargeRampUpRate (0.1%/s of rated)
            10.0,  # dischargeRampDownRate
            10.0,  # chargeRampUpRate
            10.0   # chargeRampDownRate
        ),
        maximumReactivePower=1200.0,
        minimumReactivePower=-1200.0
    )
    
    return mode
end

# =============================================================================
# Example 4: Watt-VAR Mode for Solar Coordination
# =============================================================================

"""
Create a Watt-VAR mode that coordinates reactive power with active power.
Common in solar+storage applications where reactive support increases
with active power output.
"""
function example_watt_var_mode()
    # Define active power (%) to reactive power (VAR) curve
    # At 0% active power: no reactive power
    # At 50% active power: 25% of max reactive power
    # At 100% active power: 50% of max reactive power
    watt_var_curve = VertexCurve([
        Vertex(-100.0, -600.0),  # Max charge: absorb VARs
        Vertex(-50.0, -300.0),   # Half charge: absorb less
        Vertex(0.0, 0.0),        # Zero power: no VARs
        Vertex(50.0, 300.0),     # Half discharge: inject VARs
        Vertex(100.0, 600.0)     # Max discharge: inject more VARs
    ])
    
    mode = WattVARMode(
        MesaModeParams(priority=6),
        watt_var_curve,
        activePowerReference=1000.0,  # 1000 kW reference (100%)
        minimumActivePower=10.0,      # Minimum 10 kW threshold
        maximumReactivePower=1200.0,
        minimumReactivePower=-1200.0,
        hysteresisPercent=2.0         # 2% hysteresis to prevent chatter
    )
    
    return mode
end

# =============================================================================
# Example 5: Reactive Power Limit Mode
# =============================================================================

"""
Create a reactive power limit mode to protect inverter.
Acts as a constraint on other reactive power modes.
Should typically have lower priority (higher number) so it acts as a limit.
"""
function example_reactive_power_limit_mode()
    mode = ReactivePowerLimitMode(
        MesaModeParams(priority=10),  # Low priority (acts as constraint)
        maximumReactivePowerPercent=90.0,  # Limit to 90% of rating
        minimumReactivePowerPercent=-90.0, # Limit to 90% of rating
        ratedReactivePower=1200.0          # Rated capability (VARs)
    )
    
    return mode
end

# =============================================================================
# Example 6: Multi-Mode Configuration
# =============================================================================

"""
Create a complete MESA controller with multiple reactive power modes.
This example combines:
1. High priority: Volt-VAR for voltage regulation
2. Medium priority: Power factor for utility compliance
3. Low priority: Reactive power limits for protection
"""
function example_multi_mode_controller()
    modes = MesaMode[
        # Primary voltage support (highest priority)
        example_volt_var_mode(),
        
        # Secondary power factor control
        example_power_factor_mode(),
        
        # Protection limits (lowest priority)
        example_reactive_power_limit_mode()
    ]
    
    controller = MesaController(
        modes,
        Minute(5)  # 5-minute resolution
    )
    
    return controller
end

# =============================================================================
# Example 7: Dynamic Curve Creation
# =============================================================================

"""
Create a symmetric volt-var curve programmatically.
Useful when you want to ensure symmetry or generate curves from parameters.
"""
function example_symmetric_volt_var_curve()
    # Define only the positive side
    x_points = [0.0, 1.0, 2.0, 5.0, 10.0]  # Voltage deviation (V)
    y_points = [0.0, 0.0, 200.0, 600.0, 1000.0]  # Reactive power (VAR)
    
    # Create symmetric curve
    curve = create_symmetric_curve(x_points, y_points)
    
    # Validate the curve
    if validate_curve(curve)
        println("Curve is valid")
    else
        println("Warning: Curve validation failed")
    end
    
    return curve
end

# =============================================================================
# Example 8: Testing Curve Evaluation
# =============================================================================

"""
Test curve evaluation at various points.
"""
function test_curve_evaluation()
    # Create a simple linear curve
    curve = VertexCurve([
        Vertex(0.0, 0.0),
        Vertex(100.0, 1000.0)
    ])
    
    # Test evaluation at various points
    test_points = [0.0, 25.0, 50.0, 75.0, 100.0, 150.0]
    
    println("Testing curve evaluation:")
    for x in test_points
        y = evaluate_curve(curve, x)
        println("  x=$x -> y=$y")
    end
end

# =============================================================================
# Usage Example
# =============================================================================

"""
Example of how to use these modes in an actual control scenario.
"""
function usage_example()
    # Create controller with reactive power modes
    controller = example_multi_mode_controller()
    
    # In actual use, the controller would be passed to the control function:
    # result = control(ess, controller, schedulePeriod, useCases, t, spProgress)
    
    println("Created MESA controller with $(length(controller.modes)) modes")
    for (i, mode) in enumerate(controller.modes)
        println("  Mode $i: $(typeof(mode)) - Priority $(mode.params.priority)")
    end
end
