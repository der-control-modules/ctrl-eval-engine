
using CtrlEvalEngine:
    ScheduleHistory, OperationHistory, Progress, power, VariableIntervalTimeSeries
using CtrlEvalEngine.EnergyStorageUseCases
using Dates
using LinearAlgebra

@testset "Use Cases" begin
    @testset "Energy Net Income" begin
        @test power(
            OperationHistory(
                DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
                [1.0, 1.0, 1.0, 1.0],
                zeros(4),
                ones(4),
            ),
        ) ⋅ VariableIntervalTimeSeries(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 2.0, 3.0, 4.0],
        ) == 10.0

        @test power(
            OperationHistory(
                DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
                [-1.0, -1.0, 1.0, 1.0],
                zeros(4),
                ones(4),
            ),
        ) ⋅ VariableIntervalTimeSeries(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 2.0, 3.0, 4.0],
        ) == 4.0

        @test power(
            OperationHistory(
                DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
                [-1.0, -1.0, 1.0, 1.0],
                zeros(5),
                ones(5),
            ),
        ) ⋅ VariableIntervalTimeSeries(
            DateTime(2022, 1, 1):Minute(30):DateTime(2022, 1, 1, 4),
            [1.0, 0.0, 2.0, 0.0, 3.0, 0.0, 4.0, 0.0],
        ) == 2.0

        @test power(
            OperationHistory(
                DateTime(2022, 1, 1):Minute(30):DateTime(2022, 1, 1, 4),
                [-1.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0],
                zeros(9),
                ones(9),
            ),
        ) ⋅ VariableIntervalTimeSeries(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 2.0, 3.0, 4.0],
        ) == 2.0

        @test power(
            OperationHistory(
                [
                    DateTime("2022-01-01T00:30"),
                    DateTime("2022-01-01T01:15"),
                    DateTime("2022-01-01T02:00"),
                    DateTime("2022-01-01T03:45"),
                ],
                [1.0, -1.0, 1.0],
                zeros(4),
                ones(4),
            ),
        ) ⋅ VariableIntervalTimeSeries(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 2.0, 3.0, 4.0],
        ) == 1.0 * 0.5 + 2.0 * 0.25 + 2.0 * -0.75 + 3.0 + 4.0 * 0.75

        begin
            tOperation = [
                DateTime("2022-01-01T00:30"),
                DateTime("2022-01-01T01:14"),
                DateTime("2022-01-01T01:32"),
                DateTime("2022-01-01T02:32:49"),
                DateTime("2022-01-01T02:50"),
                DateTime("2022-01-01T03:45"),
            ]

            irregularOperationIncomeMatches =
                power(
                    OperationHistory(
                        tOperation,
                        ones(length(tOperation) - 1),
                        zeros(length(tOperation)),
                        ones(length(tOperation)),
                    ),
                ) ⋅ VariableIntervalTimeSeries(
                    DateTime(2022, 1, 1):Minute(10):DateTime(2022, 1, 1, 4),
                    ones(24),
                ) ≈ 3.25

            @test irregularOperationIncomeMatches
        end
    end

    @testset "Energy Arbitrage" begin
        tOperation = [
            DateTime("2022-01-01T00:30"),
            DateTime("2022-01-01T01:14"),
            DateTime("2022-01-01T01:32"),
            DateTime("2022-01-01T02:32:49"),
            DateTime("2022-01-01T02:50"),
            DateTime("2022-01-01T03:45"),
        ]
        outputProgress = Progress(
            100,
            ScheduleHistory(
                DateTime(2022):Hour(1):DateTime(2022, 1, 1, 4),
                [0.5, 1.0, 1.0, 0],
            ),
            OperationHistory(
                tOperation,
                ones(length(tOperation) - 1),
                zeros(length(tOperation)),
                ones(length(tOperation)),
            ),
        )

        ucEA = EnergyArbitrage(
            Dict(
                "actualEnergyPrice" => Dict(
                    "Time" => [
                        "2022-01-01T00:00",
                        "2022-01-01T01:00",
                        "2022-01-01T02:00",
                        "2022-01-01T03:00",
                    ],
                    "LMP" => [10.0, 20.0, 50.0, 30.0],
                ),
            ),
        )

        @test calculate_net_benefit(outputProgress, ucEA) isa Float64
        @test calculate_metrics(outputProgress.schedule, outputProgress.operation, ucEA) isa AbstractVector
        @test use_case_charts(outputProgress.schedule, outputProgress.operation, ucEA) isa AbstractVector
    end

    @testset "Regulation/AGC" begin

    end
end