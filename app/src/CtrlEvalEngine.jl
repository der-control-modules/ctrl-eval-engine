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
function generate_output_dict(progress::Progress, useCases::AbstractVector{<:UseCase})
    metrics = mapreduce(
        uc -> calculate_metrics(progress.operation, uc),
        vcat,
        useCases,
        init=[
            Dict(
                :label => "Annual Benefit (ex.)",
                :value => "\$100K"
            ),
            Dict(
                :label => "Present Value Benefit (ex.)",
                :value => "\$6.8M"
            ),
            Dict(
                :label => "Annual Usage (Discharged Energy) (ex.)",
                :value => "10 MWh (100 cycles)"
            ),
            Dict(
                :label => "SOH Change (ex.)",
                :value => "100% → 87%"
            ),
            Dict(
                :label => "Energy Loss (ex.)",
                :value => "190 kWh"
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


function update_schedule_period_progress!(spp::SchedulePeriodProgress, actualPowerKw, duration)
    if !isempty(spp.powerKw) && spp.powerKw[end] == actualPowerKw
        spp.t[end] += duration
    else
        push!(spp.powerKw, actualPowerKw)
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
            spProgress = SchedulePeriodProgress(schedulePeriod)
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

    return generate_output_dict(progress, useCases)
end

end