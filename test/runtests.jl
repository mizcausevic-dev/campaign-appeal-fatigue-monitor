using Test
using CampaignAppealFatigueMonitor

@testset "campaign appeal fatigue monitor" begin
    scenario = sample_scenario()
    result = score_fatigue(scenario)

    @test result["coverage_pct"] >= 50
    @test length(result["segment_results"]) == 6
    @test length(result["channel_results"]) == 3
    @test result["high_fatigue_segments"] >= 1
    @test result["blocked_waves"] >= 1
    @test any(item["recommended_action"] == "pause" for item in result["segment_results"])
end
