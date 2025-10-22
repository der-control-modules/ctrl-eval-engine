using CtrlEvalEngine

struct VoltageControl <: UseCase
    meteredVoltage::TimeSeries
    referenceVoltage::Float64  # Is this an ess property already?
end
