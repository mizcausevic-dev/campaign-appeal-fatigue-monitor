include(joinpath(@__DIR__, "..", "src", "CampaignAppealFatigueMonitor.jl"))
using .CampaignAppealFatigueMonitor

result = build_dashboard()
println("Scenario: ", result["scenario_title"])
println("Coverage: ", result["coverage_pct"], "%")
println("High-fatigue segments: ", result["high_fatigue_segments"])
println("Blocked appeal waves: ", result["blocked_waves"])
