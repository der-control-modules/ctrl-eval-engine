
struct EnergyArbitrage <: UseCase
    energyPrice::TimeSeriesPrice
end

"""
    EnergyArbitrage(input)

Construct an `EnergyArbitrage` object from `input` dictionary or array
"""
EnergyArbitrage(input::Dict) = EnergyArbitrage(
    TimeSeriesPrice(
        DateTime.(input["t"]),
        Float64.(input["actualPriceData"])
    )
)

EnergyArbitrage(input::AbstractVector) = EnergyArbitrage(
    TimeSeriesPrice(
        [DateTime(row["date"]) for row in input],
        [Float64(row["lmp"]) for row in input]
    )
)

function calculate_net_income(operation, price::TimeSeriesPrice)
    @assert price.t[1] ≤ start_time(operation) && price.t[end] ≥ end_time(operation) "The time range of price should enclose that of `operation`"
    netIncome = 0
    iPrice = findfirst(price.t .> start_time(operation)) - 1
    tEndPrice = price.t[iPrice+1]

    for (tStart, tEndPower, p) in operation
        # For each operation period
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

*(operation::OperationHistory, price::TimeSeriesPrice) = calculate_net_income(operation, price)
*(price::TimeSeriesPrice, operation::OperationHistory) = calculate_net_income(operation, price)


"""
    summarize_use_case(operation, useCase)

Summarize the benefit and cost associated with `useCase` given `operation`
"""
function summarize_use_case(operation::OperationHistory, eaUseCase::EnergyArbitrage)
    return Dict(:netArbitrageIncome => operation * eaUseCase.energyPrice)
end

