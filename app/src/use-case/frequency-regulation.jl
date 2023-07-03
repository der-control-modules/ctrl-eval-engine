using CtrlEvalEngine

struct FrequencyRegulation <: UseCase
    meteredFrequency::TimeSeries
    nominalFrequency::Float64
end

