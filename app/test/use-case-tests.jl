
include("../use-case/main.jl")
using .EnergyStorageUseCases
using Dates

@testset "Use Cases" begin
    @test EnergyStorageUseCases.calculate_net_income(
        OperationHistory(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 1.0, 1.0, 1.0],
            zeros(4)
        ),
        EnergyStorageUseCases.EnergyPrice(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 2.0, 3.0, 4.0]
        )
    ) == 10.0

    @test EnergyStorageUseCases.calculate_net_income(
        OperationHistory(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [-1.0, -1.0, 1.0, 1.0],
            zeros(4)
        ),
        EnergyStorageUseCases.EnergyPrice(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 2.0, 3.0, 4.0]
        )
    ) == 4.0

    @test EnergyStorageUseCases.calculate_net_income(
        OperationHistory(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [-1.0, -1.0, 1.0, 1.0],
            zeros(5)
        ),
        EnergyStorageUseCases.EnergyPrice(
            DateTime(2022, 1, 1):Minute(30):DateTime(2022, 1, 1, 4),
            [1.0, 0.0, 2.0, 0.0, 3.0, 0.0, 4.0, 0.0]
        )
    ) == 2.0

    @test EnergyStorageUseCases.calculate_net_income(
        OperationHistory(
            DateTime(2022, 1, 1):Minute(30):DateTime(2022, 1, 1, 4),
            [-1.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0],
            zeros(9)
        ),
        EnergyStorageUseCases.EnergyPrice(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 2.0, 3.0, 4.0]
        )
    ) == 2.0

    @test EnergyStorageUseCases.calculate_net_income(
        OperationHistory(
            [
                DateTime("2022-01-01T00:30"),
                DateTime("2022-01-01T01:15"),
                DateTime("2022-01-01T02:00"),
                DateTime("2022-01-01T03:45")
            ],
            [1.0, -1.0, 1.0],
            zeros(4)
        ),
        EnergyStorageUseCases.EnergyPrice(
            DateTime(2022, 1, 1):Hour(1):DateTime(2022, 1, 1, 4),
            [1.0, 2.0, 3.0, 4.0]
        )
    ) == 1.0 * 0.5 + 2.0 * 0.25 + 2.0 * -0.75 + 3.0 + 4.0 * 0.75

    @test begin
        tOperation = [
            DateTime("2022-01-01T00:30"),
            DateTime("2022-01-01T01:14"),
            DateTime("2022-01-01T01:32"),
            DateTime("2022-01-01T02:32:49"),
            DateTime("2022-01-01T02:50"),
            DateTime("2022-01-01T03:45")
        ]
        EnergyStorageUseCases.calculate_net_income(
            OperationHistory(
                tOperation,
                ones(length(tOperation) - 1),
                zeros(length(tOperation))
            ),
            EnergyStorageUseCases.EnergyPrice(
                DateTime(2022, 1, 1):Minute(10):DateTime(2022, 1, 1, 4),
                ones(24)
            )
        ) ≈ 3.25
    end
end