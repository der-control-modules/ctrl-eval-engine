from collections import deque
from pytz import timezone
from datetime import datetime, timedelta
from itertools import islice
import pandas as pd


class TSBuffer(object):
    def __init__(self, maxlen=None, tz='UTC'):
        self.deque = deque(maxlen=maxlen)
        self.tz = tz

    def __len__(self):
        return len(self.deque)

    def append(self, value, d_time=None):
        d_time = d_time if d_time else timezone(self.tz).localize(datetime.utcnow())
        data = (d_time, value)
        self.deque.append(data)

    def maxlen(self, new_length):
        if new_length > self.deque.maxlen:
            self.deque = deque(self.deque, maxlen=new_length)

    def extend(self, values):
        self.deque.extend(values)

    def get(self, horizon=None, times=True):
        try:
            contents = self.deque
            if horizon and horizon < len(contents):
                contents = list(islice(contents, len(contents) - horizon, None))
            if times:
                contents = zip(*contents)
            else:
                contents = zip(*contents)[1]
        except Exception as e:
            print("In Buffer.get(), exception is: {}".format(str(e)))
            return [(), ()]
        else:
            return contents

    def get_series(self, horizon=0):
        horizon = horizon if horizon < len(self.deque) else 0
        contents = self.deque if not horizon else list(islice(self.deque, len(self.deque) - horizon, None))
        contents = list(zip(*contents)) if contents else [[],[]]
        return pd.Series(contents[1], contents[0])

class AMACOperation:
    def __init__(self, amac_config):

        # use case configs
        self.data_interval = 1
        self.damping_parameter = amac_config.get("dampingParameter", 8.0)
        self.max_window_size = amac_config.get("maximumAllowableWindowSize", 2100)
        self.asc_power = 0
        self.battery_output_power = 0
        self.acceleration_parameter = 0
        self.max_interval_length = 900
        self.load_total_data = TSBuffer(maxlen=self.max_interval_length)
    
        # BESS default values   
        self.bess_rated_kw = 125.0
        self.bess_rated_kwh = 200.0
        self.bess_eta = 0.925
        self.bess_soc_max = 90
        self.bess_soc_min = 10
        self.asc_power = 0
        self.battery_power = 0
        self.acceleration_parameter = 0
        self.soc_pct = 50
        
        self.bess_soc_ref = amac_config.get("referenceSocPct", 50.0)

        self.maximum_allowable_variability_pct = amac_config.get(
            "maximumAllowableVariabilityPct", 50
        )
        self.reference_variability_pct = amac_config.get("referenceVariabilityPct", 10)
        self.minimum_allowable_variability_pct = amac_config.get(
            "minimumAllowableVariabilityPct", 2
        )

        self.variability = 0.0
        self.min_variability = 0.0
        self.max_variability = 0.0
        self.ref_variability = 0.0

    
    def set_PV_rated_power(self, maximum_pv_power):
        self.min_variability = (
            maximum_pv_power * self.minimum_allowable_variability_pct
        ) / 100
        self.max_variability = (
            maximum_pv_power * self.maximum_allowable_variability_pct
        ) / 100
        self.ref_variability = (maximum_pv_power * self.reference_variability_pct) / 100

    def set_bess_data(self, rated_kw, rated_kwh, eta, soc_pct, soc_max, soc_min):
        # BESS config
        self.bess_rated_kw = rated_kw
        self.bess_rated_kwh = rated_kwh
        self.bess_eta = eta
        self.bess_soc_max = soc_max
        self.bess_soc_min = soc_min
        self.soc_pct = soc_pct

    def set_load_data(self, load_data, d_time):
        self.load_power = load_data
        self.d_time = d_time
        self.load_total_data.append(self.load_power, self.d_time)
        #print(self.load_power)

    def publish_calculations(self, value_buffer, horizon=900):
        if len(value_buffer) < horizon:
            return
        value_series = value_buffer.get_series()
        rolling_power = value_series.rolling(min_periods=horizon, window=horizon)

        self.mean = rolling_power.mean().values[-1]
        self.variability = rolling_power.std().values[-1]

    def persistence(self, buf, window_size, forecast_delta=None):
        forecast_value, forecast_time = None, None
        if len(buf) > 0:
            try:
                # TODO: Migrate to new time_series_buffer which uses since datetime instead of number of data.
                series = buf.get_series()
                #print(series)
                forecast_values = series.rolling(
                    window=window_size, min_periods=1
                ).mean()
                #print(f"forecast values = {forecast_values}")
                forecast_value = forecast_values.values[-1]
               # print(f"forecast value = {forecast_value}")
                #forecast_time = series.index[-1] + forecast_delta
                # times, data = buf.get(horizon)
                # forecast_value, forecast_time = np.mean(data), times[-1] + timedelta(seconds=horizon)
            except Exception as e:
                print("Exception in smart_persistence: {}".format(str(e)))
        return forecast_value

    def calculate_soc(self, soc_now, power):
        return (power / (self.bess_rated_kwh * self.data_interval) / 36) + soc_now

    def run_model(self):
        self.publish_calculations(self.load_total_data)
        # A window size derived from std.
        window_size = int(self.max_window_size * (self.variability - self.min_variability)/(self.variability + (
            (self.max_variability - self.variability) / self.damping_parameter)))
        #print(f"window size = {window_size}")
        if window_size > 0:
            # print(f"window_size = {window_size}")
            if self.variability > self.min_variability:
                self.acceleration_parameter = min(
                    (self.variability - self.min_variability)
                    / (self.ref_variability - self.min_variability),
                    1,)
            else:
                self.acceleration_parameter = 0

            delta_soc = float(self.soc_pct) - float(self.bess_soc_ref)
            sign = 1 if delta_soc <= 0 else -1
            if abs(delta_soc) > 0:
                self.asc_power = (
                    sign
                    * self.bess_rated_kw
                    * min(1, (abs(delta_soc) / (self.bess_soc_max - self.bess_soc_ref))
                    * self.acceleration_parameter)
                )
            else:
                self.asc_power = 0

            if self.variability < self.min_variability:
                self.asc_power = 0

            ama_power = 0
            residuals = []
            for horizon in [self.data_interval, window_size]:
                #print(f"horizon = {horizon}")
                residual_forecast = self.persistence(
                    self.load_total_data,
                    window_size=horizon,
                    forecast_delta=timedelta(seconds=self.data_interval),
                )
                # print(f"residual_forecast = {residual_forecast}")
                residuals.append(residual_forecast)
            ama_power = residuals[0] - residuals[1]
            instantaneous_residual = ama_power + self.asc_power
            self.battery_power = self.load_power - instantaneous_residual
            #self.battery_power = -self.load_power + instantaneous_residual

            # message = [
            #     {
            #         #"load_len": len(self.load_total_data),
            #         "load": self.load_total_data.get_series() if len(self.load_total_data) > 0 else None,
            #         "ama_power": ama_power,
            #         "battery_power": self.battery_power,
            #         "instantaneous_residual": instantaneous_residual,
            #         "window": window_size,
            #     }
            # ]
            #print(message)
            return self.battery_power

        return 0