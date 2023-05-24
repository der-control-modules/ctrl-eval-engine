from datetime import timedelta
from ts_buffer import TSBuffer


class AMACOperation:
    def __init__(self, amac_config):

        # use case configs
        self.data_interval = 1
        self.damping_parameter = amac_config.get("dampingParameter", 8.0)
        self.max_window_size = amac_config.get("maximumAllowableWindowSize", 2100)
        self.asc_power = 0
        self.battery_output_power = 0
        self.acceleration_parameter = 0
        
    def get_usecase_config(self, usecase_config):
        # TODO: move maximumPvPower and dependent variables out of __init__
        maximum_pv_power = usecase_config.get("maximumPvPower", 300)
        maximum_allowable_variability_pct = usecase_config.get(
            "maximumAllowableVariabilityPct", 50
        )
        reference_variability_pct = usecase_config.get("referenceVariabilityPct", 10)
        minimum_allowable_variability_pct = usecase_config.get(
            "minimumAllowableVariabilityPct", 2
        )
        self.bess_soc_ref = usecase_config.get("referenceSocPct", 50.0)
        self.variability = 0.0
        self.min_variability = (
            maximum_pv_power * minimum_allowable_variability_pct
        ) / 100
        self.max_variability = (
            maximum_pv_power * maximum_allowable_variability_pct
        ) / 100
        self.ref_variability = (maximum_pv_power * reference_variability_pct) / 100
        
    def get_bess_config(self, bess_config):
        # BESS config
        # TODO: move BESS config out of __init__
        self.bess_rated_kw = bess_config.get("bess_rated_kw", 125.0)
        self.bess_rated_kWh = bess_config.get("bess_rated_kWh", 200.0)
        self.bess_eta = bess_config.get("bess_eta", 0.925)
        self.bess_soc_max = bess_config.get("bess_soc_max", 90)
        self.bess_soc_min = bess_config.get("bess_soc_min", 10)
        

    def get_load_data(self, load_data, d_time, soc):
        self.load_power = load_data
        self.d_time = d_time
        self.soc = soc
        self.max_interval_length = 900
        self.load_total_data = TSBuffer(maxlen=self.max_interval_length)
        self.load_total_data.append(self.load_power, self.d_time)

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
            try:
                # TODO: Migrate to new time_series_buffer which uses since datetime instead of number of data.
                series = buf.get_series()
                forecast_value = series.rolling(
                    window=window_size, min_periods=1
                ).mean()[-1]
                forecast_time = series.index[-1] + forecast_delta
                # times, data = buf.get(horizon)
                # forecast_value, forecast_time = np.mean(data), times[-1] + timedelta(seconds=horizon)
            except Exception as e:
                print("Exception in smart_persistence: {}".format(str(e)))
        return forecast_value, forecast_time

    def calculate_soc(self, soc_now, power):
        return (power / (self.bess_rated_kWh * self.data_interval) / 36) + soc_now

    def run_model(self):
        self.publish_calculations(self.load_total_data)
        # A window size derived from std.
        window_size = (
            self.max_window_size * (self.variability - self.min_variability)
        ) / (
            self.variability
            + ((self.max_variability - self.variability) / self.damping_parameter)
        )

        instantaneous_residual, horizon = 0, 0

        if self.variability > self.min_variability:
            self.acceleration_parameter = min(
                (self.variability - self.min_variability)
                / (self.ref_variability - self.min_variability),
                1,)
        else:
            self.acceleration_parameter = 0

        delta_soc = float(self.soc) - float(self.bess_soc_ref)
        sign = 1 if delta_soc <= 0 else -1
        if abs(delta_soc) > 0:
            self.asc_power = (
                sign
                * self.bess_rated_kw
                * self.acceleration_parameter
                * min(1, (abs(delta_soc) / (self.bess_soc_max - self.bess_soc_ref)))
            )
        else:
            self.asc_power = 0

        if self.variability < self.min_variability:
            self.asc_power = 0

        if window_size > 0:
            residuals = []
            for horizon in [
                timedelta(seconds=self.data_interval),
                timedelta(seconds=window_size),
            ]:
                # TODO: This should have a setting for the meter to use, or should only be reading one if appropriate.
                residual_forecast, residual_forecast_time = self.persistence(
                    self.load_power,
                    window_size=horizon,
                    forecast_delta=timedelta(seconds=self.data_interval),
                )
                residuals.append(residual_forecast)
            ama_power = residuals[0] - residuals[1]
            instantaneous_residual = ama_power + self.asc_power
            self.battery_power = self.load_power - instantaneous_residual
        new_soc = self.calculate_soc(self.battery_power, self.soc)

        message = [
            {
                "ama_power": ama_power,
                "battery_power": self.battery_power,
                "instantaneous_residual": instantaneous_residual,
                "window": window_size,
            }
        ]
        print(message)
        return new_soc, instantaneous_residual, self.battery_power, window_size
