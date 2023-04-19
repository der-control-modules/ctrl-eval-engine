
"""
    EnergyPrice

`EnergyPrice` represents the energy price `price` in \$/kWh over a period of time with corresponding timestamps `t`.
`length(t)` should equal to `length(price) + 1`.
"""
struct EnergyPrice
    t::Vector{Dates.DateTime}
    value::Vector{Float64} # unit: $/kWh
end


struct EnergyArbitrage <: UseCase
    energyPrice::EnergyPrice
end

"""
    EnergyArbitrage(input)

Construct an `EnergyArbitrage` object from `input` dictionary or array
"""
EnergyArbitrage(input::Dict) = EnergyArbitrage(
    EnergyPrice(
        DateTime.(input["t"]),
        Float64.(input["actualPriceData"])
    )
)

EnergyArbitrage(input::AbstractVector) = EnergyArbitrage(
    EnergyPrice(
        [DateTime(row["date"]) for row in input],
        [Float64(row["lmp"]) for row in input]
    )
)

function calculate_net_income(operation::OperationHistory, price::EnergyPrice)
    @assert price.t[1] ≤ operation.t[1] && price.t[end] ≥ operation.t[end] "The time range of price should enclose that of `operation`"
    netIncome = 0
    iPrice = findfirst(price.t .> operation.t[1]) - 1
    tEndPrice = price.t[iPrice+1]

    for (iPower, p) in enumerate(operation.powerKw)
        # For each operation period
        tStart = operation.t[iPower]
        tEndPower = operation.t[iPower+1]
        while tStart < tEndPower && tEndPrice ≤ tEndPower
            # [tStart ----- (tEndPrice|tEndPower)] or
            # [tStart ----- tEndPrice] ----- tEndPower
            netIncome += p * price.value[iPrice] * /(promote(tEndPrice - tStart, Hour(1))...)
            tStart = tEndPrice
            iPrice += 1
            if iPrice + 1 > length(price.t)
                break
            end
            tEndPrice = price.t[iPrice+1]
        end
        if tStart < tEndPower && tEndPrice > tEndPower
            # [tStart ----- tEndPower] ----- tEndPrice
            netIncome += p * price.value[iPrice] * /(promote(tEndPower - tStart, Hour(1))...)
        end
    end
    return netIncome
end


import Base: *

*(operation::OperationHistory, price::EnergyPrice) = calculate_net_income(operation, price)
*(price::EnergyPrice, operation::OperationHistory) = calculate_net_income(operation, price)


"""
    summarize_use_case(operation, useCase)

Summarize the benefit and cost associated with `useCase` given `operation`
"""
function summarize_use_case(operation::OperationHistory, eaUseCase::EnergyArbitrage)
    return Dict(:netArbitrageIncome => operation * eaUseCase.energyPrice)
end

