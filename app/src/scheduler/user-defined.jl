
using JSON

struct UserDefinedScheduler <: Scheduler
    chIn::Channel{String}
    chOut::Channel{String}
    task::Any
end

function UserDefinedScheduler(config::Dict, ess, useCases::AbstractVector{<:UseCase})
    chIn = Channel{String}()
    chOut = Channel{String}()
    # simple websocket client
    task = @async WebSockets.open("ws://localhost:9000") do ws
        # we can iterate the websocket
        # where each iteration yields a received message
        # iteration finishes when the websocket is closed
        for msg in chOut
            # do stuff with msg
            send(ws, msg)
            put!(chIn, receive(ws))
        end
        close(chIn)
    end

    essParameters = Dict(
        "e_max_kWh" => e_max(ess),
        "e_min_kWh" => e_min(ess),
        "p_max_kW" => p_max(ess),
        "RTE_pu" => ηRT(ess),
    )

    put!(
        chOut,
        JSON.json(
            Dict(
                :type => "initialize",
                :payload => Dict(config..., :ess => essParameters, :use_cases => useCases),
            ),
        ),
    )
    responseDict = JSON.parse(take!(chIn))
    if haskey(responseDict, "error") ||
       get(responseDict, "message", nothing) !== "Initialized"
        throw(
            CtrlEvalEngine.InitializationFailure(
                get(responseDict, "error", "User-defined scheduler failed to initialize"),
            ),
        )
    end

    UserDefinedScheduler(chIn, chOut, task)
end

function schedule(
    ess,
    sch::UserDefinedScheduler,
    useCases::AbstractVector{<:UseCase},
    tStart::Dates.DateTime,
    progress::Progress,
)
    @debug "UserDefinedScheduler" t = tStart

    put!(
        sch.chOut,
        JSON.json(
            Dict(
                :current_SOC_pu => SOC(ess),
                :use_cases => useCases,
                :t => tStart,
                :op_history => Dict(
                    :timestamps => progress.operation.t,
                    :SOC_pu => progress.operation.SOC,
                    :power_kW => progress.operation.powerKw,
                ),
            ),
        ),
    )
    scheduleDict = JSON.parse(take!(sch.chIn))

    return Schedule(
        float.(scheduleDict["power_Kw"]),
        tStart;
        resolution = Second(floor(Int, 3600 * scheduleDict["resolutionHrs"])),
        SOC = [SOC(ess), float.(scheduleDict["SOC_pu"])...],
        regCapKw = scheduleDict["regulation_cap_kW"],
    )
end

function CtrlEvalEngine.cleanup(sch::UserDefinedScheduler)
    close(sch.chOut)
    wait(sch.task)
end
