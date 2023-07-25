using Dates

@testset "Fixed Interval" begin
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

@testset "Variable Interval" begin
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