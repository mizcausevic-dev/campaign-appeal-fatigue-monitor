include(joinpath(@__DIR__, "..", "src", "CampaignAppealFatigueMonitor.jl"))
using .CampaignAppealFatigueMonitor

result = build_dashboard()
root = write_site(result)
println("Generated site at: ", root)

