
using JuMP
using Clp

struct OptScheduler <: Scheduler
    resolution::Dates.Period
    interval::Dates.Period
    optWindow::Int64
end

function schedule(ess, scheduler::OptScheduler, useCases, tStart::Dates.DateTime)
    K = scheduler.optWindow
    scheduleLength = Int(ceil(scheduler.interval, scheduler.resolution) / scheduler.resolution)

    m = Model(Clp.Optimizer)
    set_optimizer_attribute(m, "LogLevel", 0)

    @variables(m, begin
        e_min(ess) ≤ eng[1:K+1] ≤ e_max(ess) # energy state
        0 ≤ p_p[1:K] ≤ p_max(ess.specs)  # discharging power into the grid
        0 ≤ p_n[1:K] ≤ -p_min(ess.specs)  # charging power from the grid
        out[1:K]   # power transfer from battery to grid
        r_p[1:K] ≥ 0  # regulation-up power
        r_n[1:K] ≥ 0   # regulation-down power
        r_c[1:K] ≥ 0  # regulation power
        spn[1:K] ≥ 0  # spinning reserve
        con[1:K]   # T&D deferral for contingency events
        pvp[1:K] ≥ 0  # PV power output
    end)

    @constraint(m, engy_intial_condition, eng[1] == energy_state(ess))
    @constraint(m, engy_final_condition, eng[end] == energy_state(ess))

    # TODO: T&D upgrade deferral
    # if !isnothing(minDeferralPower)  # T&D deferral contingency event
    #     @constraint(m, out .>= minDeferralPower)
    #     CON_Hours = findall(minDeferralPower .> 0)
    #     @constraint(m, con .== p_p .* (minDeferralPower .> 0))
    #     @constraint(m, r_p[CON_Hours] .== 0)
    #     @constraint(m, r_n[CON_Hours] .== 0)
    #     @constraint(m, spn[CON_Hours] .== 0)
    # else
        @constraint(m, con .== 0)
    # end

    if ~UOBS_regulation_flag
        @constraint(m, r_p .== 0)
        @constraint(m, r_n .== 0)
    end

    if ~UOBS_spin_reserve_flag
        @constraint(m, spn .== 0)
    end

    @constraints(m, begin
        out .== p_p .- p_n
        # energy state dynamics
        eng[2:end] .== eng[1:end-1] .- p_p ./ eta_p + p_n .* eta_n
        # regulation up
        r_p .<= p_max(ess.specs) .- out
        r_p .+ spn .≤ p_max(ess.specs) .- out
        eng .- REG_Res .* r_p .+ spn ./ eta_p .≥ 0
        # regulation down
        r_n .<= -p_min(ess.specs) .+ out
        eng .+ REG_Res .* r_n .* eta_n .<= e_max(ess)
        # regulation
        r_c .<= r_p
        r_c .<= r_n
        # TODO: PV generation dump
        pvp .== 0
    end)

    # Initialize objective function expression with energy arbitrage benefit (to be maximized)
    objective_exp = @expression(m, -EnergyStorageOpt.get_energy_cost(float.(DA_Energy_price[i:i+K-1]), -out - pvp))
    if ~UOBS_reg_separation_flag
        # regulation capacity and service performance
        objective_exp = @expression(m,
            objective_exp
            + sum(DA_Reg_price[(i-1)+k] * r_c[k] * Reg_Perf for k = 1:K)
            + sum(DA_Reg_service_price[(i-1)+k] * r_c[k] * REG_Mil[T[k]] * Reg_Perf for k = 1:K)
            + sum(DA_Spn_reserve_price[(i-1)+k] * spn[k] for k = 1:K)
        )

    else
        # regulation up and down
        objective_exp = @expression(m,
            objective_exp
            + sum(DA_Reg_up_price[(i-1)+k] * r_p[k] * Reg_Perf for k = 1:K)
            + sum(DA_Reg_dn_price[(i-1)+k] * r_n[k] * Reg_Perf for k = 1:K)
            + sum(DA_Spn_reserve_price[(i-1)+k] * spn[k] for k = 1:K)
        )

    end

    @objective(m, Max, objective_exp)
    optimize!(m)
    sol_p_p = JuMP.value.(p_p)
    sol_p_n = JuMP.value.(p_n)
    sol_r_p = JuMP.value.(r_p)
    sol_r_n = JuMP.value.(r_n)
    sol_r_c = JuMP.value.(r_c)
    sol_out = JuMP.value.(out)
    sol_eng = JuMP.value.(eng)
    sol_spn = JuMP.value.(spn)
    sol_con = JuMP.value.(con)
    sol_pvp = JuMP.value.(pvp)
    if K < scheduleLength
        append!(sol_out, zeros(scheduleLength - K))
    end
    # currentSchedule = rand(scheduleLength) .* (
    #     p_max(ess, scheduler.interval) - p_min(ess, scheduler.interval)
    # ) .+ p_min(ess, scheduler.interval)

    currentSchedule = Schedule(sol_out[1:scheduleLength], tStart, scheduler.resolution)
    @debug "Schedule updated" currentSchedule
    return currentSchedule
end
