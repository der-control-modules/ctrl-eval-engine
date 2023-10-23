using CtrlEvalEngine

struct VoltageControl <: UseCase
    meteredVoltage::TimeSeries
    referenceVoltage::Float64
end
