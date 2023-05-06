module CtrlEvalEngine
using AWSS3
using JSON
using Dates

export evaluate_controller, TimeSeries, FixedIntervalTimeSeries, VariableIntervalTimeSeries

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
    calculate_benefit_cost(operation, useCases)

Calculate the benefits and costs given `operation` and `useCases`.
"""
function calculate_benefit_cost(operation::OperationHistory, useCases::AbstractVector{<:UseCase})
    map(uc -> summarize_use_case(operation, uc), useCases)
end


function update_progress!(progress::Progress, t::Dates.DateTime, setting::SimSetting, ess::EnergyStorageSystem, powerKw::Real)
    push!(progress.operation.t, t)
    progress.progressPct = min((t - setting.simStart) / (setting.simEnd - setting.simStart), 1.0) * 100.0
    push!(progress.operation.powerKw, powerKw)
    push!(progress.operation.SOC, SOC(ess))
end

function update_progress!(scheduleHistory::ScheduleHistory, currentSchedule::EnergyStorageScheduling.Schedule)
    for schedulePeriod in currentSchedule
        push!(scheduleHistory.t, end_time(schedulePeriod))
        push!(scheduleHistory.powerKw, average_power(schedulePeriod))
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


"""
    evaluate_controller(inputDict)

Evaluate the performance of the controller specified in `inputDict`
"""
function evaluate_controller(inputDict; debug=false)
    @info "Parsing and validating input data"
    setting = get_setting(inputDict)
    ess = get_ess(inputDict["selectedBatteryCharacteristics"])
    useCases = get_use_cases(inputDict["selectedUseCasesCharacteristics"])
    scheduler = EnergyStorageScheduling.get_scheduler(inputDict["selectedControlTypeCharacteristics"]["scheduler"])
    rtController = EnergyStorageRTControl.get_rt_controller(inputDict["selectedControlTypeCharacteristics"]["rtController"], ess, useCases)

    t = setting.simStart
    progress = Progress(
        0.0,
        ScheduleHistory([t], Float64[]),
        OperationHistory([t], Float64[], Float64[SOC(ess)])
    )

    while t < setting.simEnd
        currentSchedule = EnergyStorageScheduling.schedule(ess, scheduler, useCases, t)
        update_progress!(progress.schedule, currentSchedule)
        for schedulePeriod in currentSchedule
            schedulePeriodEnd = min(end_time(schedulePeriod), setting.simEnd)
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

    useCaseResults = calculate_benefit_cost(progress.operation, useCases)

    output = Dict(
        :schedule => progress.schedule,
        :operation => progress.operation,
        :useCase => useCaseResults
    )
    return output
end

end