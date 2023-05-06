
using JSON
using CtrlEvalEngine.EnergyStorageRTControl: AMAController
using CtrlEvalEngine.EnergyStorageSimulators
using CtrlEvalEngine.EnergyStorageUseCases

amac = AMAController(JSON.parse("""
{
    "type": "ama",
    "referenceSocPct":50,
    "maximumAllowableWindowSize": 2100,
    "maximumAllowableVariabilityPct":50,
    "referenceVariabilityPct": 10,
    "activationThresholdVariabilityPct": 2,
    "dampingParameter": 8
}
"""), get_ess(JSON.parse("""
{
    "calculationType": "duration",
    "duration": 4,
    "powerCapacityUnit": "kw",
    "powerCapacityValue": 123,
    "energyCapacity": null,
    "batteryType": "lfp-lithium-ion",
    "roundtripEfficiency": 0.86,
    "cycleLife": 4000
}
""")), UseCase[])