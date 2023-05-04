
using JSON
using CtrlEvalEngine
using AWSS3

redirect_stdio(stderr=stdout)
BUCKET_NAME = get(ENV, "BUCKET_NAME", "long-running-jobs-test")

inputDict, debug, JOB_ID = if length(ARGS) == 1
    inputJobId = ARGS[1]
    (
        JSON.parse(IOBuffer(read(S3Path("s3://$BUCKET_NAME/input/$inputJobId.json")))),
        false,
        inputJobId 
    )
elseif length(ARGS) == 2 && ARGS[1] == "debug"
    (JSON.parsefile(ARGS[2]), true, nothing)
else
    @error "Unsupported command line arguments" ARGS
    exit(1)
end

outputDict = try
    evaluate_controller(inputDict, BUCKET_NAME, JOB_ID; debug)
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
