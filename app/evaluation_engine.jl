
using AWSS3
using JSON
using Dates

include("types.jl")

function get_setting(inputDict::Dict)
    simStart = Dates.DateTime(inputDict["simStart"])
    simEnd = Dates.DateTime(inputDict["simEnd"])
    SimSetting(simStart, simEnd)
end

include("simulator/main.jl")
include("scheduler/main.jl")
include("realtime-controller/main.jl")
include("use-case/main.jl")

using .EnergyStorageSimulators
using .EnergyStorageScheduling
using .EnergyStorageRTControl
using .EnergyStorageUseCases


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

function update_progress!(scheduleHistory::ScheduleHistory, t::Dates.DateTime, currentSchedule::EnergyStorageScheduling.Schedule)
    for (scheduledPowerKw, scheduleDuration) in currentSchedule
        t += scheduleDuration
        push!(scheduleHistory.t, t)
        push!(scheduleHistory.powerKw, scheduledPowerKw)
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
    scheduler = EnergyStorageScheduling.get_scheduler(inputDict["selectedControlTypeCharacteristics"])
    rtController = EnergyStorageRTControl.get_rt_controller(inputDict)

    t = setting.simStart
    progress = Progress(
        0.0,
        ScheduleHistory([t], Float64[]),
        OperationHistory([t], Float64[], Float64[SOC(ess)])
    )

    while t < setting.simEnd
        currentSchedule = EnergyStorageScheduling.schedule(ess, scheduler, useCases, t)
        update_progress!(progress.schedule, t, currentSchedule)
        for (scheduledPowerKw, scheduleDuration) in currentSchedule
            schedulePeriodEnd = min(t + scheduleDuration, setting.simEnd)
            operations = control(ess, rtController, (scheduledPowerKw, scheduleDuration), useCases, t)
            for (operationPowerKw, controlDuration) in operations
                actualPowerKw = operate!(ess, operationPowerKw, controlDuration)
                t += controlDuration
                update_progress!(progress, t, setting, ess, actualPowerKw)
                if t > setting.simEnd
                    break
                end
            end
            if t < schedulePeriodEnd
                @warn "Gap detected from end of control at $t to end of scheduling period $schedulePeriodEnd. ESS stays idle."
                operate!(ess, 0.0, schedulePeriodEnd - t)
                t = schedulePeriodEnd
                update_progress!(progress, t, setting, ess, 0.0)
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


redirect_stdio(stderr=stdout)

inputDict, debug = if length(ARGS) == 1
    JOB_ID = ARGS[1]
    BUCKET_NAME = get(ENV, "BUCKET_NAME", "long-running-jobs-test")
    (JSON.parse(IOBuffer(read(S3Path("s3://$BUCKET_NAME/input/$JOB_ID.json")))), false)
elseif length(ARGS) == 2 && ARGS[1] == "debug"
    (JSON.parsefile(ARGS[2]), true)
else
    @error "Unsupported command line arguments" ARGS
    exit(1)
end

outputDict = try
    evaluate_controller(inputDict; debug)
catch e
    if isa(e, InvalidInput)
        @error("Invalid input")
    else
        @error("Something went wrong during evaluation")
    end
    Dict(:error => string(e))
end

if debug
    open(ARGS[2][1:end-5] * "_output.json", "w") do f
        JSON.print(f, outputDict)
    end
else
    @info "Uploading output data"
    s3_put(BUCKET_NAME, "output/$JOB_ID.json", JSON.json(outputDict))
end
@info "Exiting"
