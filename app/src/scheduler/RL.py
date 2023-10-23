# -*- coding: utf-8 -*-
"""
Created on Mon Mar 27 14:29:51 2023

@author: dasa880
"""


import numpy as np
import itertools
import random


def RL(price, use_case, approach, resolution_hrs, Battery_parameters, iteration, epsilon_update=1.07):
    K = len(price)
    RL_parameters = {"iteration": iteration, "epsilon_initial": 0.7, "epsilon_interval": 50*K/24, "epsilon_update": epsilon_update, "alpha": 1, "gamma": 1, "discrete": 20}
    delta = (
        Battery_parameters["soc_high"] - Battery_parameters["soc_low"]
    ) / RL_parameters["discrete"]
    states = np.arange(
        Battery_parameters["soc_low"], Battery_parameters["soc_high"], delta
    )
    states = np.round(states, 2)
    time_states = np.arange(0, K)

    c = list(itertools.product(time_states, states))
    Q_table = np.zeros([len(c), len(states)])

    ep_update = RL_parameters["epsilon_interval"]
    epsilon = RL_parameters["epsilon_initial"]

    for i in range(iteration):
        batt_state = Battery_parameters["initial_soc"]
        total_cost = 0

        if i == ep_update:
            epsilon = epsilon / epsilon_update
            ep_update = ep_update + RL_parameters["epsilon_interval"]

        Batt_action = []
        Batt_power = []

        for t in range(K):
            status = np.ones(len(states))
            powerbatt = (states - batt_state) * Battery_parameters["energy"] / resolution_hrs
            index_ch = [idx for idx, val in enumerate(powerbatt) if val > 0]
            index_dis = [idx for idx, val in enumerate(powerbatt) if val < 0]
            power = powerbatt
            power[index_ch] = power[index_ch] / Battery_parameters["efficiency"]
            power[index_dis] = power[index_dis] * Battery_parameters["efficiency"]
            index_inf = [
                idx
                for idx, val in enumerate(power)
                if val > Battery_parameters["power"]
                or val < -Battery_parameters["power"]
            ]
            status[index_inf] = 0
            help_assign = [idx for idx, val in enumerate(status) if val > 0]
            if t == 0:
                dist = abs(states - batt_state)
                min_index = dist.argmin()
                idx_current_state = c.index((t, states[min_index]))
            else:
                idx_current_state = c.index((t, batt_state))

            if random.uniform(0, 1) < epsilon:
                rand_action = random.randint(1, len(help_assign))
                action = help_assign[rand_action - 1]
                if use_case == "energy_arbitrage":
                    cost = -power[action] * price[t]
                if use_case == "frequency_regulation":
                    cost = abs(power[action]) * price[t]
            else:
                Q_action = np.argmax(Q_table[idx_current_state, help_assign])
                action = help_assign[Q_action]
                if use_case == "energy_arbitrage":
                    cost = -power[action] * price[t]
                if use_case == "frequency_regulation":
                    cost = abs(power[action]) * price[t]

            next_time = t + 1
            next_soc = states[action]
            Batt_power.append(power[action])

            if next_time < K:
                if approach == "SARSA":
                    next_state = c.index((next_time, next_soc))
                    status = np.ones(len(states))
                    powerbatt = (states - next_soc) * Battery_parameters["energy"] / resolution_hrs
                    index_ch_nxt = [idx for idx, val in enumerate(powerbatt) if val > 0]
                    index_dis_nxt = [
                        idx for idx, val in enumerate(powerbatt) if val < 0
                    ]
                    power_nxt = powerbatt
                    power_nxt[index_ch_nxt] = (
                        power[index_ch_nxt] / Battery_parameters["efficiency"]
                    )
                    power_nxt[index_dis_nxt] = (
                        power[index_dis_nxt] * Battery_parameters["efficiency"]
                    )
                    index_inf_nxt = [
                        idx
                        for idx, val in enumerate(power_nxt)
                        if val > Battery_parameters["power"]
                        or val < -Battery_parameters["power"]
                    ]
                    status[index_inf_nxt] = 0
                    help_assign_nxt = [idx for idx, val in enumerate(status) if val > 0]

                    if random.uniform(0, 1) < epsilon:
                        rand_action = random.randint(1, len(help_assign_nxt))
                        next_action = help_assign_nxt[rand_action - 1]
                        next_max = Q_table[next_state, next_action]
                    else:
                        Q_action = np.argmax(Q_table[next_state, help_assign_nxt])
                        next_action = help_assign_nxt[Q_action]
                        next_max = Q_table[next_state, next_action]

                else:
                    next_state = c.index((next_time, next_soc))
                    next_max = np.max(Q_table[next_state])
            else:
                next_max = 0

            old_value = Q_table[idx_current_state, action]

            new_value = (1 - RL_parameters["alpha"]) * old_value + RL_parameters[
                "alpha"
            ] * (cost + RL_parameters["gamma"] * next_max)
            Q_table[idx_current_state, action] = new_value

            batt_state = next_soc
            total_cost = total_cost + cost
            Batt_action.append(next_soc)

    return total_cost, Batt_action, Batt_power
