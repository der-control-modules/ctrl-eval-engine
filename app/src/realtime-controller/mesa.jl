module MesaEss

    using Dates
    using CtrlEvalEngine.EnergyStorageSimulators
    using CtrlEvalEngine.EnergyStorageUseCases: UseCase, LoadFollowing
    using CtrlEvalEngine.EnergyStorageScheduling: SchedulePeriod

    struct MesaController <: RTController
        priority::Int
        timeWindow::Dates.Second
        rampTime::Dates.Second
        reversionTimeout::Dates.Second
    end

    struct Vertex
        x::Float64
        y::Float64
    end

    struct VertexCurve
        vertices::Array{Vertex}
    end

    struct RampParams
        rampUpTimeConstant::Dates.Second
        rampDownTimeConstant::Dates.Second
        dischargeRampUpRate::Float64
        dischargeRampDownRate::Float64
        chargeRampUpRate::Float64
        chargeRampDownRate::Float64
    end
    
    struct WorkInProgress
        controlOps::Array{Float64}
    end
end
