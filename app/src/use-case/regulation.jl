
import Base: *, zero
struct RegulationPricePoint
    capacityPrice::Float64
    servicePrice::Float64
end

Base.:zero(::RegulationPricePoint) = RegulationPricePoint(0, 0)
Base.:zero(::Type{RegulationPricePoint}) = RegulationPricePoint(0, 0)

struct RegulationOperationPoint{
    TC<:Union{Real,JuMP.AbstractJuMPScalar},
    TM<:Union{Real,JuMP.AbstractJuMPScalar},
}
    capacity::TC
    mileage::TM
end

Base.:zero(
    ::RegulationOperationPoint{TC,TM},
) where {TC<:Union{Real,JuMP.AbstractJuMPScalar},TM<:Union{Real,JuMP.AbstractJuMPScalar}} =
    RegulationOperationPoint(zero(TC), zero(TM))

Base.:zero(
    ::Type{RegulationOperationPoint{TC,TM}},
) where {TC<:Union{Real,JuMP.AbstractJuMPScalar},TM<:Union{Real,JuMP.AbstractJuMPScalar}} =
    RegulationOperationPoint(zero(TC), zero(TM))

struct Regulation <: UseCase
    AGCSignalPu::TimeSeries{Float64}
    price::FixedIntervalTimeSeries{<:Dates.TimePeriod,RegulationPricePoint}
    performanceScore::Float64
end

Regulation(input::Dict, tStart::DateTime, tEnd::DateTime) = begin
    agcCore = FixedIntervalTimeSeries(
        DateTime(input["agcSignal"]["DateTime"][1]),
        DateTime(input["agcSignal"]["DateTime"][2]) -
        DateTime(input["agcSignal"]["DateTime"][1]),
        float.(input["agcSignal"]["Dispatch_pu"]),
    )
    @debug "Constructing Regulation object" inputAgc = input["agcSignal"]
    Regulation(
        if get(input["agcSignal"], "repeated", false)
            RepeatedTimeSeries(agcCore, tStart, tEnd)
        else
            extract(agcCore, tStart, tEnd)
        end,
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
end

function regulation_income(
    regOperation::TimeSeries{<:RegulationOperationPoint},
    ucReg::Regulation,
)
    (ucReg.price ⋅ regOperation) * ucReg.performanceScore
end

Base.:*(pp::RegulationPricePoint, op::RegulationOperationPoint) =
    pp.capacityPrice * op.capacity + pp.servicePrice * op.capacity * op.mileage
Base.:*(op::RegulationOperationPoint, pp::RegulationPricePoint) =
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

calculate_net_benefit(progress::Progress, ucReg::Regulation) = begin
    @debug "Calculating Regulation benefit" schedule = progress.schedule regHistory =
        regulation_history(progress.schedule, ucReg) regPriceLen = length(ucReg.price)
    regulation_income(regulation_history(progress.schedule, ucReg), ucReg)
end

function calculate_metrics(sh::ScheduleHistory, op::OperationHistory, ucReg::Regulation)
    regIncome = regulation_income(regulation_history(sh, ucReg), ucReg)
    tsError =
        ucReg.AGCSignalPu * VariableIntervalTimeSeries(sh.t, sh.regCapKw) -
        (power(op) - power(sh))
    rmse = round(sqrt(mean(tsError^2)); sigdigits = 2)
    return [
        Dict(:sectionTitle => "Frequency Regulation"),
        Dict(:label => "Revenue", :value => regIncome, :type => "currency"),
        Dict(:label => "AGC Signal Following RMSE", :value => "$rmse kW"),
    ]
end

function use_case_charts(sh::ScheduleHistory, op::OperationHistory, ucReg::Regulation)
    scaledAgcSignal = ucReg.AGCSignalPu * VariableIntervalTimeSeries(sh.t, sh.regCapKw)
    actualRegPower = power(op) - power(sh)
    [
        Dict(
            :title => "Frequency Regulation",
            :height => "300px",
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
                    :x => timestamps(ucReg.price),
                    :y => map(
                        (pricePoint::RegulationPricePoint) -> pricePoint.capacityPrice,
                        get_values(ucReg.price),
                    ),
                    :type => "interval",
                    :name => "Regulation Capacity Price",
                    :yAxis => "right",
                ),
                Dict(
                    :x => timestamps(ucReg.price),
                    :y => map(
                        (pricePoint::RegulationPricePoint) -> pricePoint.servicePrice,
                        get_values(ucReg.price),
                    ),
                    :type => "interval",
                    :name => "Mileage Price",
                    :yAxis => "right",
                ),
            ],
        ),
        Dict(
            :height => "300px",
            :xAxis => Dict(:title => "Time"),
            :yAxisLeft => Dict(:title => "Power (kW)"),
            :data => [
                Dict(
                    :x => timestamps(scaledAgcSignal),
                    :y => get_values(scaledAgcSignal),
                    :type => "interval",
                    :line => Dict(:dash => :dot),
                    :name => "AGC Signal",
                ),
                Dict(
                    :x => timestamps(actualRegPower),
                    :y => get_values(actualRegPower),
                    :type => "interval",
                    :name => "Actual Power",
                ),
            ],
        ),
    ]
end