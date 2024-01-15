
abstract type DemandChargeRateStructure end

struct FlatDemandChargeRateStructure <: DemandChargeRateStructure
    rate::Float64
end

struct MonthlyDemandChargeRateStructure <: DemandChargeRateStructure
    monthlyRates::Vector{Float64}
end

# TODO: TOU demand charge rate structure
struct TOUDemandChargeRateStructure <: DemandChargeRateStructure end

struct DemandChargeReduction <: UseCase
    rateStructure::DemandChargeRateStructure
    loadForecastKw15min::FixedIntervalTimeSeries
end

function DemandChargeReduction(
    config::Dict,
    simStart::Dates.DateTime,
    simEnd::Dates.DateTime,
)
    loadForecastKw15min = extract(
        FixedIntervalTimeSeries(
            config["loadForecast15min"]["timestamp"][1],
            Minute(15),
            config["loadForecast15min"]["load_kW"],
        ),
        simStart,
        simEnd,
    )
    if config["rate"] isa Number
        DemandChargeReduction(
            FlatDemandChargeRateStructure(config["rate"]),
            loadForecastKw15min,
        )
    elseif config["rate"] isa Vector
        DemandChargeReduction(
            MonthlyDemandChargeRateStructure(config["rate"]),
            loadForecastKw15min,
        )
    end
end

function demand_charge(rateStructure::FlatDemandChargeRateStructure, load::TimeSeries)
    monthStart = floor(start_time(load), Minute(15))
    monthEnd = firstdayofmonth(monthStart + Month(1))
    demandCharge = 0
    while monthEnd ≤ end_time(load)
        # For each month except the last incomplete month
        loadMonth15min = mean(load, monthStart:Minute(15):monthEnd)
        monthPeak = maximum(loadMonth15min)
        demandCharge += monthPeak * rateStructure.rate
        monthStart = monthEnd
        monthEnd = firstdayofmonth(monthStart + Month(1))
    end

    if monthStart < end_time(load)
        # Last incomplete month
        monthEnd = ceil(end_time(load), Minute(15))
        loadMonth15min = mean(load, monthStart:Minute(15):monthEnd)
        monthPeak = maximum(loadMonth15min)
        demandCharge += monthPeak * rateStructure.rate
    end
end

function demand_charge(rateStructure::MonthlyDemandChargeRateStructure, load::TimeSeries)
    monthStart = floor(start_time(load), Minute(15))
    monthEnd = firstdayofmonth(monthStart + Month(1))
    demandCharge = 0
    while monthEnd ≤ end_time(load)
        # For each month except the last incomplete month
        loadMonth15min = mean(load, monthStart:Minute(15):monthEnd)
        monthPeak = maximum(loadMonth15min)
        demandCharge += monthPeak * rateStructure.monthlyRates[month(monthStart)]
        monthStart = monthEnd
        monthEnd = firstdayofmonth(monthStart + Month(1))
    end

    if monthStart < end_time(load)
        # Last incomplete month
        monthEnd = ceil(end_time(load), Minute(15))
        loadMonth15min = mean(load, monthStart:Minute(15):monthEnd)
        monthPeak = maximum(loadMonth15min)
        demandCharge += monthPeak * rateStructure.monthlyRates[month(monthStart)]
    end
end

demand_charge(ucDCR::DemandChargeReduction, extraPower::TimeSeries) =
    demand_charge(ucDCR.rateStructure, ucDCR.loadForecastKw15min - extraPower)

function demand_charge_periods_rates(
    rateStructure::FlatDemandChargeRateStructure,
    netLoad::TimeSeries,
)
    months = []
    rates = []
    monthStart = floor(start_time(netLoad), Minute(15))
    monthEnd = firstdayofmonth(monthStart + Month(1))
    while monthEnd ≤ end_time(netLoad)
        # For each month except the last incomplete month
        loadMonth15min = mean(netLoad, monthStart:Minute(15):monthEnd)
        push!(months, [get_values(loadMonth15min)])
        push!(rates, [rateStructure.rate])
        monthStart = monthEnd
        monthEnd = firstdayofmonth(monthStart + Month(1))
    end

    if monthStart < end_time(netLoad)
        # Last incomplete month
        monthEnd = ceil(end_time(netLoad), Minute(15))
        loadMonth15min = mean(netLoad, monthStart:Minute(15):monthEnd)
        push!(months, [get_values(loadMonth15min)])
        push!(rates, [rateStructure.rate])
    end
    return months, rates
end

function demand_charge_periods_rates(
    rateStructure::MonthlyDemandChargeRateStructure,
    netLoad::TimeSeries,
)
    months = []
    rates = []
    monthStart = floor(start_time(netLoad), Minute(15))
    monthEnd = firstdayofmonth(monthStart + Month(1))
    while monthEnd ≤ end_time(netLoad)
        # For each month except the last incomplete month
        loadMonth15min = mean(netLoad, monthStart:Minute(15):monthEnd)
        push!(months, [get_values(loadMonth15min)])
        push!(rates, [rateStructure.monthlyRates[month(monthStart)]])
        monthStart = monthEnd
        monthEnd = firstdayofmonth(monthStart + Month(1))
    end

    if monthStart < end_time(netLoad)
        # Last incomplete month
        monthEnd = ceil(end_time(netLoad), Minute(15))
        loadMonth15min = mean(netLoad, monthStart:Minute(15):monthEnd)
        push!(months, [get_values(loadMonth15min)])
        push!(rates, [rateStructure.monthlyRates[month(monthStart)]])
    end
    return months, rates
end
