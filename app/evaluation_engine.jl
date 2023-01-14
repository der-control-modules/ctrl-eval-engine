
using AWSS3
using JSON
using Dates

include("simulator/main.jl")
include("scheduler/main.jl")
include("realtime-controller/main.jl")

using .EnergyStorageSimulators
using .EnergyStorageScheduling
using .EnergyStorageRTControl

struct SimSetting
    simStart::Dates.DateTime
    simEnd::Dates.DateTime
end

struct ScheduleHistory
    t::Vector{Dates.DateTime}
    powerKw::Vector{Float64}
end

struct OperationHistory
    t::Vector{Dates.DateTime}
    powerKw::Vector{Float64}
    SOC::Vector{Float64}
end

mutable struct Progress
    progressPct::Float64
    schedule::ScheduleHistory
    operation::OperationHistory
end

function get_setting(inputDict::Dict)
    simStart = Dates.DateTime(inputDict["simStart"])
    simEnd = Dates.DateTime(inputDict["simEnd"])
    SimSetting(simStart, simEnd)
end

function get_use_cases(inputDict::Dict)
    return nothing
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
    ess = get_ess(inputDict)
    useCases = get_use_cases(inputDict)
    scheduler = EnergyStorageScheduling.get_scheduler(inputDict)
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
                operate!(ess, operationPowerKw, controlDuration)
                t += controlDuration
                update_progress!(progress, t, setting, ess, operationPowerKw)
                if t > setting.simEnd
                    break
                end
            end
            if t < schedulePeriodEnd
                @warn "Gap from end of control at $t to end of scheduling period $schedulePeriodEnd"
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

    @warn "Sample warning message"
    output = Dict(:schedule => progress.schedule, :operation => progress.operation)
    return output
end


if length(ARGS) ∉ (1, 2)
    @error "Command line argument INPUT_PATH is required" ARGS
    exit(1)
end

redirect_stdio(stderr=stdout)

if length(ARGS) == 1
    JOB_ID = ARGS[1]
    BUCKET_NAME = get(ENV, "BUCKET_NAME", "long-running-jobs-test")
    inputDict = JSON.parse(IOBuffer(read(S3Path("s3://$BUCKET_NAME/input/$JOB_ID.json"))))
    outputDict = try
        evaluate_controller(inputDict)
    catch e
        @error("Something went wrong during evaluation")
        Dict(:error => e)
    end
    @info "Uploading output data"
    s3_put(BUCKET_NAME, "output/$JOB_ID.json", JSON.json(outputDict))
elseif ARGS[1] == "debug"
    inputDict = JSON.parsefile(ARGS[2])
    @time outputDict = evaluate_controller(inputDict, debug=true)
    open(ARGS[2][1:end-5] * "_output.json", "w") do f
        JSON.print(f, outputDict)
    end
else
    @error "Unsupported command line arguments" ARGS
end
@info "Exiting"