
include("src/CtrlEvalEngine.jl")

using JSON
using .CtrlEvalEngine

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
    if debug
        throw(e)
    end
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
