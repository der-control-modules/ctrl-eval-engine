using CtrlEvalEngine.EnergyStorageRTControl: Vertex, VertexCurve

"""
    evaluate_curve(curve::VertexCurve, x::Float64)

Evaluate a piecewise linear curve defined by vertices at point x.
Performs linear interpolation between vertices.

# Arguments
- `curve::VertexCurve`: The curve to evaluate, defined by an array of Vertex points
- `x::Float64`: The x-coordinate at which to evaluate the curve

# Returns
- `Float64`: The interpolated y-value at point x

# Notes
- If x is below the first vertex, returns the y-value of the first vertex
- If x is above the last vertex, returns the y-value of the last vertex
- Vertices should be sorted by x-coordinate for correct interpolation
"""
function evaluate_curve(curve::VertexCurve, x::Float64)
    vertices = curve.vertices
    
    # Handle empty curve
    if isempty(vertices)
        return 0.0
    end
    
    # Handle single vertex
    if length(vertices) == 1
        return vertices[1].y
    end
    
    # Sort vertices by x-coordinate (in case they're not sorted)
    sorted_vertices = sort(vertices, by = v -> v.x)
    
    # Check if x is before the first vertex
    if x <= sorted_vertices[1].x
        return sorted_vertices[1].y
    end
    
    # Check if x is after the last vertex
    if x >= sorted_vertices[end].x
        return sorted_vertices[end].y
    end
    
    # Find the two vertices to interpolate between
    for i in 1:(length(sorted_vertices) - 1)
        v1 = sorted_vertices[i]
        v2 = sorted_vertices[i + 1]
        
        if x >= v1.x && x <= v2.x
            # Linear interpolation: y = y1 + (y2 - y1) * (x - x1) / (x2 - x1)
            if v2.x == v1.x
                # Avoid division by zero
                return v1.y
            end
            
            slope = (v2.y - v1.y) / (v2.x - v1.x)
            return v1.y + slope * (x - v1.x)
        end
    end
    
    # Fallback (should not reach here)
    return 0.0
end

"""
    evaluate_curve_with_hysteresis(curve::VertexCurve, x::Float64, previous_y::Float64, hysteresis::Float64)

Evaluate a piecewise linear curve with hysteresis to prevent rapid oscillations.

# Arguments
- `curve::VertexCurve`: The curve to evaluate
- `x::Float64`: The x-coordinate at which to evaluate the curve
- `previous_y::Float64`: The previous y-value
- `hysteresis::Float64`: The hysteresis band width in y-axis units

# Returns
- `Float64`: The interpolated y-value with hysteresis applied

# Notes
- The output only changes if the new value differs from the previous value by more than the hysteresis band
"""
function evaluate_curve_with_hysteresis(
    curve::VertexCurve,
    x::Float64,
    previous_y::Float64,
    hysteresis::Float64
)
    new_y = evaluate_curve(curve, x)
    
    # Apply hysteresis
    if abs(new_y - previous_y) > hysteresis
        return new_y
    else
        return previous_y
    end
end

"""
    create_symmetric_curve(x_points::Vector{Float64}, y_points::Vector{Float64})

Create a symmetric curve from positive quadrant data.
Useful for creating symmetric volt-var or watt-var curves.

# Arguments
- `x_points::Vector{Float64}`: X-coordinates for positive side
- `y_points::Vector{Float64}`: Y-coordinates for positive side

# Returns
- `VertexCurve`: A symmetric curve with both positive and negative sides

# Example
```julia
# Create a symmetric volt-var curve
x_points = [0.0, 2.0, 5.0]  # Voltage deviation in volts
y_points = [0.0, 500.0, 1000.0]  # Reactive power in VARs
curve = create_symmetric_curve(x_points, y_points)
# Result: vertices at (-5,-1000), (-2,-500), (0,0), (2,500), (5,1000)
```
"""
function create_symmetric_curve(x_points::Vector{Float64}, y_points::Vector{Float64})
    if length(x_points) != length(y_points)
        error("x_points and y_points must have the same length")
    end
    
    # Create negative side (reversed order)
    negative_vertices = [Vertex(-x_points[i], -y_points[i]) for i in length(x_points):-1:2]
    
    # Create positive side
    positive_vertices = [Vertex(x_points[i], y_points[i]) for i in 1:length(x_points)]
    
    # Combine both sides
    all_vertices = vcat(negative_vertices, positive_vertices)
    
    return VertexCurve(all_vertices)
end

"""
    validate_curve(curve::VertexCurve)

Validate that a curve has properly ordered vertices and is well-formed.

# Arguments
- `curve::VertexCurve`: The curve to validate

# Returns
- `Bool`: true if curve is valid, false otherwise

# Checks
- Vertices are sorted by x-coordinate
- No duplicate x-coordinates
- At least 2 vertices for a meaningful curve
"""
function validate_curve(curve::VertexCurve)
    vertices = curve.vertices
    
    if length(vertices) < 2
        @warn "Curve has fewer than 2 vertices"
        return false
    end
    
    # Check if vertices are sorted
    for i in 1:(length(vertices) - 1)
        if vertices[i].x > vertices[i + 1].x
            @warn "Vertices are not sorted by x-coordinate"
            return false
        end
        
        if vertices[i].x == vertices[i + 1].x
            @warn "Duplicate x-coordinates found at index $i"
            return false
        end
    end
    
    return true
end
