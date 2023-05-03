import pyomo.environ as pyo
from datetime import datetime, timedelta
from numpy.random import rand
from typing import List
import pandas as pd
from ts_buffer import TSBuffer


class AMACOperation:
    def __init__(self, load_data, d_time, soc, bess_config, usecase_config):
        self.load_power = load_data
        self.d_time = d_time
        self.soc = soc
        self.max_interval_length = 900
        self.load_total_data = TSBuffer(maxlen=self.max_interval_length)
        self.load_total_data.append(self.load_power, self.d_time)
        
        #use case configs
        self.damping_parameter = usecase_config.get("damping_parameter", 8.)
        self.max_window_size = usecase_config.get("Maximum_allowable_window_size", 2100)
        maximum_pv_power = usecase_config.get("Maximum_pv_power", 300)
        maximum_allowable_variability_pct = usecase_config.get("maximum_allowable_variability_pct", 50)
        refrence_variability_pct = usecase_config.get("refrence_variability_pct", 10)
        minimum_allowable_variability_pct = usecase_config.get("minimum_allowable_variability_pct", 2)
        self.min_variability = (maximum_pv_power * minimum_allowable_variability_pct)/100
        self.max_variability = (maximum_pv_power  * maximum_allowable_variability_pct)/100
        self.sigma_ref = (maximum_pv_power * refrence_variability_pct)/100
        
        #bess config
        self.bess_rated_kw = bess_config.get("bess_rated_kw", 125.)
        self.building_power_min = bess_config.get("building_power_min", 0.)
        self.bess_chg_max = bess_config.get("bess_chg_max", 100.)
        self.bess_dis_max = bess_config.get("bess_dis_max", 100.)
        self.bess_rated_kWh = bess_config.get("bess_rated_kWh", 200.)
        self.demand_charge = bess_config.get("demand_charge", 10)
        self.bess_eta = bess_config.get("bess_eta", 0.925)
        self.soc_ref = bess_config.get("bess_soc_ref", 50.)
        self.bess_soc_max = bess_config.get("bess_soc_max", 90)
        self.bess_soc_min = bess_config.get("bess_soc_min", 10)
        self.s_charge = self.bess_soc_init
        self.pr = 0
        self.p_update = 0
        self.csi = TSBuffer(maxlen=900)
        

    def gets(self, data):
        data.index = data.index.tz_localize('UTC')
        data = data.resample('1S').mean().fillna(method='pad').fillna(method='backfill')
        data.index = data.index.tz_convert('US/Eastern')
        return data

    def vaja(self, data1,data2):
        data = pd.concat([data1, -data2], axis=1)
        data = data.sum(axis=1)
        return data

    def window(self, data,x):
        load_power_mean =data.rolling(min_periods=1, window=x).mean()
        return load_power_mean

    def sdwindow(self, data,x):
        load_power_std = data.rolling(min_periods=x, window=x).std()
        return load_power_std
    
    def publish_calculations(self, value_buffer, horizon=900):
        if len(value_buffer) < horizon:
            return
        value_series = value_buffer.get_series()
        rolling_power = value_series.rolling(min_periods=horizon, window=horizon)

        self.mean = rolling_power.mean()[-1]
        self.variability = rolling_power.std()[-1]
        
        
        
    def persistence(self, buf, window_size, forecast_delta=None):
        forecast_value, forecast_time = None, None
        if len(buf) > 0:
            if not forecast_delta or not isinstance(forecast_delta, timedelta):
                forecast_delta = window_size
            try:
                # TODO: Migrate to new time_series_buffer which uses since datetime instead of number of data.
                series = buf.get_series()
                forecast_value = series.rolling(window=window_size, min_periods=1).mean()[-1]
                forecast_time = series.index[-1] + forecast_delta
                #times, data = buf.get(horizon)
                #forecast_value, forecast_time = np.mean(data), times[-1] + timedelta(seconds=horizon)
            except Exception as e:
                print("Exception in smart_persistence: {}".format(str(e)))
        return forecast_value, forecast_time
    
    def run_model(self, soc):
        self.publish_calculations(self.load_total_data)
        # A window size derived from std.
        window_size = (self.max_window_size * (self.variability - self.min_variability)) /\
                      (self.variability + ((self.max_variability - self.variability)/self.damping_parameter))

        mean_component = 0
        instantaneous_residual, buffered_residual, instantaneous_csi, buffered_csi, horizon = 0, 0, 0, 0, 0
        delta_soc = float(self.soc) - float(self.soc_ref)
        s = abs(delta_soc) - self.soc_thr
        sign = 1 if delta_soc <= 0 else -1
        if s > 0:
            self.p_update = sign * min(self.prmax, (self.prmax * \
                                               pow(((s / (self.soc_max - self.soc_thr))), 1)))
        if self.variability < self.min_variability:
            p_update = 0

        if window_size > 0:
            residuals = []
            for horizon in [timedelta(seconds=1), timedelta(seconds=5), timedelta(seconds=window_size)]:
                # TODO: This should have a setting for the meter to use, or should only be reading one if appropriate.
                residual_forecast, residual_forecast_time = self.persistence(
                    self.load_power,
                    window_size=horizon,
                    forecast_delta=timedelta(seconds=self.run_model_interval)
                )
                residuals.append(residual_forecast)
            ama_power = residuals[0] - residuals[2]
            instantaneous_residual = ama_power + p_update
            buffered_residual = residuals[1] - residuals[2]
            mean_component = residuals[2]

        message = [
            {
             'mean_component': mean_component,
             'instantaneous_residual': instantaneous_residual,
             'buffered_residual': buffered_residual,
             'window': window_size
             }]
        return message
