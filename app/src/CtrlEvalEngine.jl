module CtrlEvalEngine
using AWSS3
using JSON
using Dates

export evaluate_controller, TimeSeries, FixedIntervalTimeSeries, VariableIntervalTimeSeries, InvalidInput

include("types.jl")

function get_setting(inputDict::Dict)
    simStart = Dates.DateTime(inputDict["simStart"])
    simEnd = Dates.DateTime(inputDict["simEnd"])
    SimSetting(simStart, simEnd)
end

include("simulator/main.jl")
include("use-case/main.jl")
include("scheduler/main.jl")
include("realtime-controller/main.jl")

using .EnergyStorageSimulators
using .EnergyStorageUseCases
using .EnergyStorageScheduling
using .EnergyStorageRTControl


"""
    generate_output_dict(progress, useCases)

Generate the output dictionary according to `progress` and `useCases`.
"""
function generate_output_dict(progress::Progress, useCases::AbstractVector{<:UseCase}, ess::EnergyStorageSystem)
    netBenefit = mapreduce(uc -> calculate_net_benefit(progress, uc), +, useCases)
    simPeriodLengthInYear = (end_time(progress.operation) - start_time(progress.operation)) / Day(365)
    annualBenefit = netBenefit / simPeriodLengthInYear

    # Capital recovery factor
    discount = 0.0685
    cbaYears = 20
    CRF = discount + discount / ((1 + discount)^cbaYears - 1)

    pvBenefit = annualBenefit / CRF

    # Annual usage
    dischargedEnergyKwh = discharged_energy(progress.operation)
    annualDischargedEnergyKwh = dischargedEnergyKwh / simPeriodLengthInYear
    annualCycles = round(annualDischargedEnergyKwh / e_max(ess), sigdigits=2)
    annualDischargedEnergyMwh = round(annualDischargedEnergyKwh / 1000, sigdigits=3)
    annualUsageString = (
        annualDischargedEnergyKwh ≥ 1000 ?
        "$annualDischargedEnergyMwh MWh" :
        "$(round(annualDischargedEnergyKwh, sigdigits=3)) kWh"
    ) * " ($annualCycles cycles)"
    energyLossKwh = charged_energy(progress.operation) - dischargedEnergyKwh

    endingSohPct = round(SOH(ess) * 100)

    metrics = mapreduce(
        uc -> calculate_metrics(progress.operation, uc),
        vcat,
        useCases,
        init=[
            Dict(
                :label => "Annual Benefit",
                :value => "\$$annualBenefit"
            ),
            Dict(
                :label => "Present Value Benefit",
                :value => "\$$pvBenefit"
            ),
            Dict(
                :label => "Annual Usage (Discharged Energy)",
                :value => annualUsageString
            ),
            Dict(
                :label => "SOH Change",
                :value => "100% → $endingSohPct%"
            ),
            Dict(
                :label => "Energy Loss",
                :value => energyLossKwh ≥ 1000 ?
                          "$(round(energyLossKwh / 1000, sigdigits=3)) MWh" :
                          "$(round(energyLossKwh, sigdigits=3)) kWh"
            ),
        ]
    )
    outputDict = Dict(
        :metrics => metrics,
        :timeCharts => generate_chart_data(progress)
    )
    return outputDict
end


function update_progress!(progress::Progress, t::Dates.DateTime, setting::SimSetting, ess::EnergyStorageSystem, powerKw::Real)
    push!(progress.operation.t, t)
    progress.progressPct = min((t - setting.simStart) / (setting.simEnd - setting.simStart), 1.0) * 100.0
    push!(progress.operation.powerKw, powerKw)
    push!(progress.operation.SOC, SOC(ess))
    push!(progress.operation.SOH, SOH(ess))
end

function update_progress!(scheduleHistory::ScheduleHistory, currentSchedule::EnergyStorageScheduling.Schedule)
    for schedulePeriod in currentSchedule
        push!(scheduleHistory.t, EnergyStorageScheduling.end_time(schedulePeriod))
        push!(scheduleHistory.powerKw, EnergyStorageScheduling.average_power(schedulePeriod))
    end
end


function update_schedule_period_progress!(spp::VariableIntervalTimeSeries, actualPowerKw, duration::Dates.Period)
    if !isempty(spp.value) && spp.value[end] == actualPowerKw
        spp.t[end] += duration
    else
        push!(spp.value, actualPowerKw)
        push!(spp.t, spp.t[end] + duration)
    end
end

function generate_chart_data(progress::Progress)
    [
        Dict(
            :title => "ESS Operation",
            :height => "400px",
            :xAxis => Dict(:label => "Time"),
            :yAxisLeft => Dict(:label => "Power (kW)"),
            :yAxisRight => Dict(:label => "SOC (%)"),
            :data => [
                Dict(
                    :x => progress.schedule.t,
                    :y => progress.schedule.powerKw,
                    :type => "interval",
                    :name => "Scheduled Power"
                ),
                Dict(
                    :x => progress.operation.t,
                    :y => progress.operation.powerKw,
                    :type => "interval",
                    :name => "Actual Power"
                ),
                Dict(
                    :x => progress.operation.t,
                    :y => progress.operation.SOC,
                    :type => "instance",
                    :name => "Actual SOC",
                    :yAxis => "right"
                ),
            ]
        ),
        Dict(
            :title => "Cumulative Degradation",
            :height => "300px",
            :xAxis => Dict(:label => "Time"),
            :yAxisLeft => Dict(:label => "SOH (%)"),
            :data => [
                Dict(
                    :x => progress.operation.t,
                    :y => progress.operation.SOH,
                    :type => "instance",
                    :name => "ESS State of Health"
                ),
            ]
        )
    ]
end

"""
    evaluate_controller(inputDict)

Evaluate the performance of the controller specified in `inputDict`
"""
function evaluate_controller(inputDict, BUCKET_NAME, JOB_ID; debug=false)
    @info "Parsing and validating input data"
    setting = get_setting(inputDict)
    ess = get_ess(inputDict["selectedBatteryCharacteristics"])
    useCases = get_use_cases(inputDict["selectedUseCasesCharacteristics"])
    scheduler = EnergyStorageScheduling.get_scheduler(inputDict["selectedControlTypeCharacteristics"]["scheduler"])
    rtController = EnergyStorageRTControl.get_rt_controller(inputDict["selectedControlTypeCharacteristics"]["rtController"])

    t = setting.simStart
    progress = Progress(
        0.0,
        ScheduleHistory([t], Float64[]),
        OperationHistory([t], Float64[], Float64[SOC(ess)], Float64[SOH(ess)])
    )

    while t < setting.simEnd
        currentSchedule = EnergyStorageScheduling.schedule(ess, scheduler, useCases, t)
        update_progress!(progress.schedule, currentSchedule)
        for schedulePeriod in currentSchedule
            schedulePeriodEnd = min(EnergyStorageScheduling.end_time(schedulePeriod), setting.simEnd)
            spProgress = VariableIntervalTimeSeries([t], Float64[])
            while t < schedulePeriodEnd
                controlSequence = control(ess, rtController, schedulePeriod, useCases, t, spProgress)
                for (powerSetpointKw, controlDuration) in controlSequence
                    actualPowerKw = operate!(ess, powerSetpointKw, controlDuration)
                    update_schedule_period_progress!(spProgress, actualPowerKw, controlDuration)
                    t += controlDuration
                    update_progress!(progress, t, setting, ess, actualPowerKw)
                    if t > schedulePeriodEnd
                        break
                    end
                end
            end
        end
        if debug
            @debug "Progress updated" progress
        else
            s3_put(BUCKET_NAME, "$JOB_ID/progress.json", JSON.json(progress))
        end
    end

    return generate_output_dict(progress, useCases, ess)
end

end