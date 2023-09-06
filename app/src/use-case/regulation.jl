
struct RegulationPricePoint
    capacityPrice::Float64
    servicePrice::Float64
end

Base.:zero(::RegulationPricePoint) = RegulationPricePoint(0, 0)
Base.:zero(::Type{RegulationPricePoint}) = RegulationPricePoint(0, 0)

struct RegulationOperationPoint{
    TC<:Union{Real,JuMP.VariableRef},
    TM<:Union{Real,JuMP.VariableRef},
}
    capacity::TC
    mileage::TM
end

Base.:zero(::RegulationOperationPoint) = RegulationOperationPoint(0, 0)
Base.:zero(::Type{RegulationOperationPoint}) = RegulationOperationPoint(0, 0)

struct Regulation <: UseCase
    AGCSignalPu::FixedIntervalTimeSeries{<:Dates.TimePeriod,Float64}
    price::FixedIntervalTimeSeries{<:Dates.TimePeriod,RegulationPricePoint}
    performanceScore::Float64
end

Regulation(input::Dict, tStart::DateTime, tEnd::DateTime) = Regulation(
    extract(
        FixedIntervalTimeSeries(
            DateTime(input["agcSignal"]["DateTime"][1]),
            DateTime(input["agcSignal"]["DateTime"][2]) -
            DateTime(input["agcSignal"]["DateTime"][1]),
            float.(input["agcSignal"]["Dispatch_pu"]),
        ),
        tStart,
        tEnd,
    ),
    extract(
        FixedIntervalTimeSeries(
            DateTime(input["regulationPrices"]["Time"][1]),
            DateTime(input["regulationPrices"]["Time"][2]) -
            DateTime(input["regulationPrices"]["Time"][1]),
            [
                RegulationPricePoint(cap / 1000, mil / 1000) for (cap, mil) in zip(
                    input["regulationPrices"]["CapacityPrice_per_MW"],
                    input["regulationPrices"]["MileagePrice_per_MW"],
                )
            ],
        ),
        tStart,
        tEnd,
    ),
    input["performanceFactor"],
)

function regulation_income(
    regOperation::TimeSeries{<:RegulationOperationPoint},
    ucReg::Regulation,
)
    (ucReg.price ⋅ regOperation) * ucReg.performanceScore
end

import Base: *
*(pp::RegulationPricePoint, op::RegulationOperationPoint) =
    pp.capacityPrice * op.capacity + pp.servicePrice * op.capacity * op.mileage
*(op::RegulationOperationPoint, pp::RegulationPricePoint) =
    pp.capacityPrice * op.capacity + pp.servicePrice * op.capacity * op.mileage

function regulation_history(sh::ScheduleHistory, ucReg::Regulation)
    VariableIntervalTimeSeries(
        sh.t,
        [
            RegulationOperationPoint(
                cap,
                sum(
                    abs.(
                        diff(
                            get_values(
                                ucReg.AGCSignalPu,
                                sh.t[iSchedulePeriod],
                                sh.t[iSchedulePeriod+1],
                            ),
                        )
                    ),
                ),
            ) for (iSchedulePeriod, cap) in enumerate(sh.regCapKw)
        ],
    )
end

calculate_net_benefit(progress::Progress, ucReg::Regulation) =
    regulation_income(regulation_history(progress.schedule, ucReg), ucReg)

function calculate_metrics(sh::ScheduleHistory, ::OperationHistory, ucReg::Regulation)
    regIncome = regulation_income(regulation_history(sh, ucReg), ucReg)
    return [
        Dict(:sectionTitle => "Frequency Regulation"),
        Dict(:label => "Revenue", :value => regIncome, :type => "currency"),
        Dict(:label => "AGC Signal Following RMSE (ex.)", :value => 1.34e-3),
    ]
end

function use_case_charts(sh::ScheduleHistory, op::OperationHistory, ucReg::Regulation)
    scaledAgcSignal = ucReg.AGCSignalPu * VariableIntervalTimeSeries(sh.t, sh.regCapKw)
    [
        Dict(
            :title => "Frequency Regulation",
            :xAxis => Dict(:title => "Time"),
            :yAxisLeft => Dict(:title => "Power (kW)"),
            :yAxisRight => Dict(:title => raw"Price ($/kWh)"),
            :data => [
                Dict(
                    :x => sh.t,
                    :y => sh.regCapKw,
                    :type => "interval",
                    :name => "Scheduled Capacity",
                ),
                Dict(
                    :x => timestamps(scaledAgcSignal),
                    :y => get_values(scaledAgcSignal),
                    :type => "interval",
                    :name => "AGC Signal",
                ),
                Dict(
                    :x => op.t,
                    :y => op.powerKw,
                    :type => "interval",
                    :name => "Actual Power",
                ),
                Dict(
                    :x => timestamps(ucReg.price),
                    :y => map(
                        (pricePoint::RegulationPricePoint) -> pricePoint.capacityPrice,
                        get_values(ucReg.price),
                    ),
                    :type => "interval",
                    :name => "Regulation Capacity Price",
                    :yAxis => "right",
                ),
            ],
        ),
    ]
end