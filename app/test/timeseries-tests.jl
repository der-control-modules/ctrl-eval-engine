using Dates
using LinearAlgebra

@testset "Fixed Interval" begin
    @testset "Extraction" begin
        ts1 = FixedIntervalTimeSeries(DateTime(2022), Hour(1), collect(1:5))
        ts2 = extract(ts1, DateTime(2022, 1, 1, 2), DateTime(2022, 1, 1, 4))
        @test ts2 isa FixedIntervalTimeSeries
        @test all(ts2.value .== [3, 4])

        ts3 = extract(ts1, DateTime(2022, 1, 1, 1, 30), DateTime(2022, 1, 1, 4, 30))
        @test ts3 isa VariableIntervalTimeSeries
        @test all(
            timestamps(ts3) .== [
                DateTime(2022, 1, 1, 1, 30),
                DateTime(2022, 1, 1, 2),
                DateTime(2022, 1, 1, 3),
                DateTime(2022, 1, 1, 4),
                DateTime(2022, 1, 1, 4, 30),
            ],
        )
        @test all(ts3.value .== 2:5)
    end

    @testset "Integral Operations" begin
        ts1 = FixedIntervalTimeSeries(DateTime(2023), Hour(1), collect(1:5))
        @test integrate(ts1) == sum(1:5)
        @test integrate(ts1, DateTime(2023, 1, 1, 2), DateTime(2023, 1, 1, 5)) == sum(3:5)
        @test mean(ts1) == 3
        @test mean(ts1, DateTime(2023, 1, 1, 1), DateTime(2023, 1, 1, 3)) == 2.5

        ts2 = FixedIntervalTimeSeries(DateTime(2023), Minute(15), collect(1:5))
        @test integrate(ts2) == sum(1:5) / 4
        @test integrate(ts2, DateTime(2023, 1, 1, 1), DateTime(2023, 1, 1, 5)) == 5 / 4
        @test mean(ts2) == 3
        @test mean(ts2, DateTime(2023, 1, 1, 1), DateTime(2023, 1, 1, 3)) == 5 / 4 / 2
    end
end

@testset "Variable Interval" begin
    @testset "Extraction" begin
        ts1 = VariableIntervalTimeSeries(
            DateTime(2022):Hour(1):DateTime(2022, 1, 1, 5),
            collect(1:5),
        )

        ts2 = extract(ts1, DateTime(2022, 1, 1, 1), DateTime(2022, 1, 1, 4))
        @test ts2 isa VariableIntervalTimeSeries
        @test all(
            timestamps(ts2) .== [
                DateTime(2022, 1, 1, 1),
                DateTime(2022, 1, 1, 2),
                DateTime(2022, 1, 1, 3),
                DateTime(2022, 1, 1, 4),
            ],
        )
        @test all(ts2.value .== 2:4)

        ts3 = extract(ts1, DateTime(2022, 1, 1, 1, 30), DateTime(2022, 1, 1, 4, 30))
        @test ts3 isa VariableIntervalTimeSeries
        @test all(
            timestamps(ts3) .== [
                DateTime(2022, 1, 1, 1, 30),
                DateTime(2022, 1, 1, 2),
                DateTime(2022, 1, 1, 3),
                DateTime(2022, 1, 1, 4),
                DateTime(2022, 1, 1, 4, 30),
            ],
        )
        @test all(ts3.value .== 2:5)
    end

    @testset "Binary Operations" begin
        t = [
            DateTime("2022-01-01T00:30"),
            DateTime("2022-01-01T01:14"),
            DateTime("2022-01-01T01:32"),
            DateTime("2022-01-01T02:32:49"),
            DateTime("2022-01-01T02:50"),
            DateTime("2022-01-01T03:45"),
        ]

        irregularIntervalMatches =
            VariableIntervalTimeSeries(t, ones(length(t) - 1)) ⋅
            VariableIntervalTimeSeries(
                DateTime(2022, 1, 1):Minute(10):DateTime(2022, 1, 1, 4),
                ones(24),
            ) ≈ 3.25

        @test irregularIntervalMatches

        tsSum =
            VariableIntervalTimeSeries(
                [DateTime(2023), DateTime(2023, 1, 1, 1), DateTime(2023, 1, 1, 1, 30)],
                [2, 3],
            ) + VariableIntervalTimeSeries(
                [
                    DateTime(2023, 1, 1, 0, 20),
                    DateTime(2023, 1, 1, 0, 50),
                    DateTime(2023, 1, 1, 1, 15),
                    DateTime(2023, 1, 1, 2, 30),
                ],
                [2, 3, 5],
            )
        @test all(
            timestamps(tsSum) .== [
                DateTime(2023),
                DateTime(2023, 1, 1, 0, 20),
                DateTime(2023, 1, 1, 0, 50),
                DateTime(2023, 1, 1, 1),
                DateTime(2023, 1, 1, 1, 15),
                DateTime(2023, 1, 1, 1, 30),
                DateTime(2023, 1, 1, 2, 30),
            ],
        )
        @test all(get_values(tsSum) .== [2, 4, 5, 6, 8, 5])

        tsProd =
            VariableIntervalTimeSeries(
                [DateTime(2023), DateTime(2023, 1, 1, 1), DateTime(2023, 1, 1, 1, 30)],
                [2, 3],
            ) * VariableIntervalTimeSeries(
                [
                    DateTime(2023, 1, 1, 0, 20),
                    DateTime(2023, 1, 1, 0, 50),
                    DateTime(2023, 1, 1, 1, 15),
                    DateTime(2023, 1, 1, 2, 30),
                ],
                [2, 3, 5],
            )
        @test all(
            timestamps(tsProd) .== [
                DateTime(2023),
                DateTime(2023, 1, 1, 0, 20),
                DateTime(2023, 1, 1, 0, 50),
                DateTime(2023, 1, 1, 1),
                DateTime(2023, 1, 1, 1, 15),
                DateTime(2023, 1, 1, 1, 30),
                DateTime(2023, 1, 1, 2, 30),
            ],
        )
        @test all(get_values(tsProd) .== [0, 4, 6, 9, 15, 0])
    end

    @testset "Integral Operations" begin
        ts1 = VariableIntervalTimeSeries(
            [
                DateTime(2023, 1, 1, 0, 20),
                DateTime(2023, 1, 1, 0, 50),
                DateTime(2023, 1, 1, 1, 15),
                DateTime(2023, 1, 1, 2, 30),
            ],
            [2, 3, 5],
        )
        @test integrate(ts1) ≈ 2 * 0.5 + 3 * 25 / 60 + 5 * 75 / 60
        @test integrate(ts1, DateTime(2023, 1, 1, 1), DateTime(2023, 1, 1, 5)) ≈
              3 * 15 / 60 + 5 * 75 / 60
        @test mean(ts1) ≈ (2 * 30 + 3 * 25 + 5 * 75) / 130
        @test mean(ts1, DateTime(2023, 1, 1, 1), DateTime(2023, 1, 1, 3)) ≈
              (3 * 15 + 5 * 75) / 120
    end
end