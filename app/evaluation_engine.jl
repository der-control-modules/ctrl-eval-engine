
using AWSS3
using JSON

"""
    evaluate_controller(inputDict)

Evaluate the performance of the controller specified in `inputDict`
"""
function evaluate_controller(inputDict)
    @info "Starting"
    for step in 1:60
        @info "Evaluating..." step
        sleep(1)
    end

    @warn "Sample warning message"
    @error "Sample error message"
    output = Dict(:sample_key => "Sample value")
    return output
end


if length(ARGS) != 1
    @error "Command line argument INPUT_PATH is required" ARGS
    exit(1)
end

redirect_stdio(stderr=stdout)

JOB_ID = ARGS[1]
BUCKET_NAME = get(ENV, "BUCKET_NAME", "long-running-jobs-test")

inputDict = JSON.parse(IOBuffer(read(S3Path("s3://$BUCKET_NAME/input/$JOB_ID.json"))))
outputDict = evaluate_controller(inputDict)
outputPath = S3Path("s3://$BUCKET_NAME/$JOB_ID/output.json")
@info "Uploading output data"
s3_put(BUCKET_NAME, "$JOB_ID/output.json", JSON.json(outputDict))
@info "Exiting"