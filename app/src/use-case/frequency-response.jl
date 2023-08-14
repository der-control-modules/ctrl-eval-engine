using CtrlEvalEngine

struct FrequencyResponse <: UseCase
    meteredFrequency::TimeSeries
    nominalFrequency::Float64
end

