from datetime import datetime, timedelta
from numpy.random import rand
from typing import List
import pandas as pd
import pickle


class AMACOperation:
    def __init__(self, power_data, bess_config, usecase_config):
        self.load_power = power_data
        self.coeff_variance = pd.DataFrame([])
        self.windowsize = pd.DataFrame([])
        self.state_charge = pd.DataFrame([])
        self.soc_recovery = pd.DataFrame([])

        # use case configs
        self.damping_parameter = usecase_config.get("damping_parameter", 8.0)
        self.Tmax = usecase_config.get("Maximum_allowable_window_size", 2100)
        maximum_pv_power = usecase_config.get("Maximum_pv_power", 300)
        maximum_allowable_variability_pct = usecase_config.get(
            "maximum_allowable_variability_pct", 50
        )
        refrence_variability_pct = usecase_config.get("refrence_variability_pct", 10)
        minimum_allowable_variability_pct = usecase_config.get(
            "minimum_allowable_variability_pct", 2
        )
        self.sigma_min = (maximum_pv_power * minimum_allowable_variability_pct) / 100
        self.sigma_max = (maximum_pv_power * maximum_allowable_variability_pct) / 100
        self.sigma_ref = (maximum_pv_power * refrence_variability_pct) / 100

        # bess config
        self.bess_rated_kw = bess_config.get("bess_rated_kw", 125.0)
        self.building_power_min = bess_config.get("building_power_min", 0.0)
        self.bess_chg_max = bess_config.get("bess_chg_max", 100.0)
        self.bess_dis_max = bess_config.get("bess_dis_max", 100.0)
        self.bess_rated_kWh = bess_config.get("bess_rated_kWh", 200.0)
        self.demand_charge = bess_config.get("demand_charge", 10)
        self.bess_chg_eta = bess_config.get("bess_eta", 0.925)
        self.bess_dis_eta = bess_config.get("bess_eta", 0.975)
        self.bess_soc_init = bess_config.get("bess_soc_initial", 50.0)
        self.bess_soc_ref = bess_config.get("bess_soc_ref", 50.0)
        self.bess_soc_max = bess_config.get("bess_soc_max", 90)
        self.bess_soc_min = bess_config.get("bess_soc_min", 10)
        self.s_charge = self.bess_soc_init

    def gets(self, data):
        data.index = data.index.tz_localize("UTC")
        data = data.resample("1S").mean().fillna(method="pad").fillna(method="backfill")
        data.index = data.index.tz_convert("US/Eastern")
        return data

    def vaja(self, data1, data2):
        data = pd.concat([data1, -data2], axis=1)
        data = data.sum(axis=1)
        return data

    def window(self, data, x):
        load_power_mean = data.rolling(min_periods=1, window=x).mean()
        return load_power_mean

    def sdwindow(self, data, x):
        load_power_std = data.rolling(min_periods=x, window=x).std()
        return load_power_std

    def amv(self):
        load_power = self.load_power
        load_power_residual_main = pd.DataFrame([])
        MA_10_min = self.sdwindow(load_power, 600)
        pr = 0
        p_update = 0

        for i in load_power.index:
            p = (
                self.Tmax
                * (MA_10_min.double_value[i] - self.sigma_min)
                / (
                    MA_10_min.double_value[i]
                    + (
                        (self.sigma_max - MA_10_min.double_value[i])
                        / self.damping_parameter
                    )
                )
            )

            if p > 0:
                b = self.window(load_power, timedelta(seconds=p)).double_value[i]
                pv_residual = load_power.double_value[i] - b
                pv_residual = pv_residual + p_update

            else:
                b = load_power.double_value[i]
                pv_residual = load_power.double_value[i] - b

            pr = pr + pv_residual
            self.s_charge = (pr / (self.bess_rated_kWh * 36)) + self.bess_soc_ref
            delta_soc = self.s_charge - self.bess_soc_init
            sign = 1 if delta_soc <= 0 else -1

            if MA_10_min.double_value[i] > self.sigma_min:
                g1 = min(
                    (
                        (MA_10_min.double_value[i] - self.sigma_min)
                        / (self.sigma_ref - self.sigma_min)
                    ),
                    1,
                )
            else:
                g1 = 0

            if abs(delta_soc) > 0:
                p_update = sign * min(
                    self.bess_rated_kw,
                    self.bess_rated_kw
                    * (abs(delta_soc) / (self.bess_soc_max - self.bess_soc_init))
                    * g1,
                )
            else:
                p_update = 0

            df = pd.DataFrame({"pv": [pv_residual], "ts": [i]})
            df1 = pd.DataFrame({"pv": [self.s_charge], "ts": [i]})
            df2 = pd.DataFrame({"pv": [p_update], "ts": [i]})
            self.state_charge = self.state_charge.append(df1)
            load_power_residual_main = load_power_residual_main.append(df)
            coeff_var = pd.DataFrame({"pv": [p], "ts": [i]})
            self.windowsize = self.windowsize.append(coeff_var)
            self.soc_recovery = self.soc_recovery.append(df2)

        load_power_residual_main = load_power_residual_main.set_index("ts")
        load_power_residual_main = (
            load_power_residual_main.resample("1S")
            .mean()
            .fillna(method="pad")
            .fillna(method="backfill")
        )
        pv_main_mean = self.vaja(load_power, load_power_residual_main)

        self.state_charge = self.state_charge.set_index("ts")
        self.state_charge = (
            self.state_charge.resample("1S")
            .mean()
            .fillna(method="pad")
            .fillna(method="backfill")
        )
        self.soc_recovery = self.soc_recovery.set_index("ts")
        self.soc_recovery = (
            self.soc_recovery.resample("1S")
            .mean()
            .fillna(method="pad")
            .fillna(method="backfill")
        )
        self.windowsize = self.windowsize.set_index("ts")
        return pv_main_mean, self.state_charge, self.soc_recovery, self.windowsize
