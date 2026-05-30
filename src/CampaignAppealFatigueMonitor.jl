# SPDX-License-Identifier: AGPL-3.0-or-later

module CampaignAppealFatigueMonitor

using Dates

export DonorChannel, AppealSegment, AppealScenario, sample_scenario, score_fatigue, build_dashboard, write_site

struct DonorChannel
    id::String
    label::String
    weekly_capacity::Int
    stewardship_buffer::Int
    reliability::Float64
end

struct AppealSegment
    id::String
    label::String
    channel_index::Int
    households::Int
    send_cadence_days::Int
    response_decay::Float64
    fatigue_index::Float64
    stewardship_gap_days::Int
end

struct AppealScenario
    title::String
    generated_on::Date
    channels::Vector{DonorChannel}
    segments::Vector{AppealSegment}
    approval_window_days::Int
end

function sample_scenario()
    channels = [
        DonorChannel("CH-1", "Email and donor automation lane", 3, 14, 0.93),
        DonorChannel("CH-2", "Direct mail and print lane", 2, 21, 0.88),
        DonorChannel("CH-3", "Major-gift and stewardship lane", 1, 30, 0.97),
    ]

    segments = [
        AppealSegment("AP-11", "Monthly givers under renewal pressure", 1, 1840, 7, 0.82, 0.91, 9),
        AppealSegment("AP-15", "Lapsed donors in reactivation wave", 1, 2260, 10, 0.71, 0.67, 16),
        AppealSegment("AP-21", "Event attendees pending follow-up", 2, 940, 12, 0.64, 0.58, 22),
        AppealSegment("AP-27", "Foundation and grant-aligned stewards", 3, 84, 30, 0.29, 0.22, 41),
        AppealSegment("AP-34", "Emergency-campaign repeat responders", 1, 1280, 5, 0.88, 0.95, 6),
        AppealSegment("AP-39", "Board-network warm introductions", 3, 52, 21, 0.31, 0.34, 27),
    ]

    AppealScenario(
        "Campaign appeal fatigue monitor for cadence safety, donor trust, and stewardship posture",
        Date(2026, 5, 30),
        channels,
        segments,
        10,
    )
end

function segment_status(fatigue::Float64, cadence::Int, gap::Int)
    if fatigue >= 0.85 || gap <= 7 || cadence <= 5
        return "red"
    elseif fatigue >= 0.6 || gap <= 14
        return "yellow"
    else
        return "green"
    end
end

recommended_action(status::String) = status == "red" ? "pause" : status == "yellow" ? "review" : "send"

function score_fatigue(scenario::AppealScenario)
    segment_results = Any[]

    for segment in scenario.segments
        status = segment_status(segment.fatigue_index, segment.send_cadence_days, segment.stewardship_gap_days)
        coverage = round((1 - segment.fatigue_index * 0.45) * 100; digits=1)
        push!(segment_results, Dict(
            "id" => segment.id,
            "label" => segment.label,
            "channel" => scenario.channels[segment.channel_index].label,
            "households" => segment.households,
            "send_cadence_days" => segment.send_cadence_days,
            "response_decay" => round(segment.response_decay * 100; digits=1),
            "fatigue_index" => round(segment.fatigue_index * 100; digits=1),
            "stewardship_gap_days" => segment.stewardship_gap_days,
            "coverage" => coverage,
            "status" => status,
            "recommended_action" => recommended_action(status),
        ))
    end

    channel_results = Any[]
    for channel in scenario.channels
        attached = [segment for segment in segment_results if segment["channel"] == channel.label]
        red_count = count(segment -> segment["status"] == "red", attached)
        utilization = round(length(attached) / max(channel.weekly_capacity, 1) * 100; digits=1)
        push!(channel_results, Dict(
            "id" => channel.id,
            "label" => channel.label,
            "weekly_capacity" => channel.weekly_capacity,
            "stewardship_buffer" => channel.stewardship_buffer,
            "reliability" => round(channel.reliability * 100; digits=1),
            "segments" => length(attached),
            "red_segments" => red_count,
            "utilization" => utilization,
            "status" => red_count >= 2 ? "red" : red_count == 1 ? "yellow" : "green",
        ))
    end

    high_fatigue_segments = count(item -> item["status"] == "red", segment_results)
    blocked_waves = count(item -> item["recommended_action"] == "pause", segment_results)
    review_segments = count(item -> item["recommended_action"] == "review", segment_results)
    safe_send_segments = count(item -> item["recommended_action"] == "send", segment_results)
    coverage_pct = round(safe_send_segments / length(segment_results) * 100; digits=1)

    return Dict(
        "scenario_title" => scenario.title,
        "generated_on" => string(scenario.generated_on),
        "approval_window_days" => scenario.approval_window_days,
        "high_fatigue_segments" => high_fatigue_segments,
        "blocked_waves" => blocked_waves,
        "review_segments" => review_segments,
        "safe_send_segments" => safe_send_segments,
        "coverage_pct" => coverage_pct,
        "segment_results" => segment_results,
        "channel_results" => channel_results,
    )
end

build_dashboard() = score_fatigue(sample_scenario())

escape_html(text) = replace(string(text), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

function json_string(value)
    if value isa Dict
        parts = ["\"$(escape_html(k))\":$(json_string(v))" for (k, v) in value]
        return "{" * join(parts, ",") * "}"
    elseif value isa AbstractVector
        return "[" * join(json_string.(value), ",") * "]"
    elseif value isa String
        return "\"" * replace(value, "\"" => "\\\"") * "\""
    elseif value isa Bool
        return value ? "true" : "false"
    elseif value isa Number
        return string(value)
    else
        return "\"" * replace(string(value), "\"" => "\\\"") * "\""
    end
end

function base_css()
    return """
    :root{
      --bg:#070a0f; --panel:#0b1220; --panel2:#0a1426;
      --line:rgba(120,255,170,.18); --line2:rgba(120,255,170,.10);
      --text:#e9f3ff; --muted:rgba(233,243,255,.72); --muted2:rgba(233,243,255,.55);
      --bert:#37ff8b; --bert2:#19c7ff; --warn:#ffcc66; --bad:#ff5c7a; --plum:#b88cff;
      --shadow:0 18px 60px rgba(0,0,0,.55); --radius:18px;
      --mono:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Courier New",monospace;
      --sans:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;
    }
    *{box-sizing:border-box} html,body{height:100%}
    body{
      margin:0;font-family:var(--sans);color:var(--text);
      background:
        radial-gradient(1200px 600px at 20% -10%, rgba(55,255,139,.18), transparent 60%),
        radial-gradient(900px 520px at 90% 0%, rgba(25,199,255,.16), transparent 55%),
        radial-gradient(1000px 600px at 50% 110%, rgba(55,255,139,.10), transparent 60%),
        linear-gradient(180deg,#05070c 0%,#070a0f 35%,#05070c 100%);
    }
    .grid-bg{position:fixed;inset:0;pointer-events:none;opacity:.12;z-index:-1;background-image:
      linear-gradient(to right, rgba(55,255,139,.14) 1px, transparent 1px),
      linear-gradient(to bottom, rgba(55,255,139,.10) 1px, transparent 1px);
      background-size:46px 46px;mask-image: radial-gradient(900px 600px at 40% 10%, #000 60%, transparent 100%);}
    .wrap{max-width:1280px;margin:0 auto;padding:24px 22px 80px}
    .topbar{display:flex;justify-content:space-between;align-items:flex-start;gap:14px;border-bottom:1px solid var(--line2);padding-bottom:14px;margin-bottom:22px;font-family:var(--mono);font-size:11px;letter-spacing:.16em;color:var(--muted);text-transform:uppercase}
    .topbar .left{color:var(--bert)} .topbar .right{text-align:right}
    .herorow{display:grid;grid-template-columns:1.45fr .85fr;gap:18px} @media (max-width:1000px){.herorow{grid-template-columns:1fr}}
    .hero,.panel,.mini,.tablewrap{
      background:linear-gradient(180deg, rgba(11,18,32,.95), rgba(8,14,26,.92));
      border:1px solid var(--line);border-radius:22px;box-shadow:var(--shadow)
    }
    .hero{padding:28px 28px 24px;border-top:2px solid var(--bert2)}
    .hero h1{font-size:64px;line-height:.95;margin:0 0 18px;font-weight:800;letter-spacing:-.5px}
    @media (max-width:700px){.hero h1{font-size:42px}}
    .hero p,.panel p,.mini p,.tablewrap p{color:var(--muted);font-size:15px;line-height:1.55}
    .chiprow{display:flex;flex-wrap:wrap;gap:8px}
    .meta-chip,.pill{font-family:var(--mono);font-size:11px;padding:7px 12px;border-radius:999px;border:1px solid var(--line);background:rgba(6,10,18,.4);color:var(--muted)}
    .side{display:flex;flex-direction:column;gap:14px}
    .mini{padding:18px}
    .mini .lbl,.section-note{font-family:var(--mono);font-size:10px;letter-spacing:.18em;text-transform:uppercase;color:var(--bert2)}
    .mini h3{margin:8px 0 6px;font-size:28px;line-height:1.02}
    .section{margin-top:34px}
    .sh{display:flex;justify-content:space-between;align-items:baseline;gap:14px;padding-bottom:10px;border-bottom:1px solid var(--line2);margin-bottom:14px}
    .sh h2{margin:0;font-size:24px;font-weight:600}
    .sh .note{font-family:var(--mono);font-size:11px;color:var(--muted2);letter-spacing:.16em;text-transform:uppercase}
    .kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px} @media (max-width:900px){.kpis{grid-template-columns:repeat(2,1fr)}} @media (max-width:640px){.kpis{grid-template-columns:1fr}}
    .kpi,.card{border:1px solid var(--line);border-radius:16px;padding:16px;background:linear-gradient(180deg, rgba(11,18,32,.85), rgba(8,14,26,.65))}
    .kpi .v{font-family:var(--mono);font-size:28px;font-weight:700}
    .kpi .lbl{font-family:var(--mono);font-size:10px;letter-spacing:.18em;text-transform:uppercase;color:var(--muted);margin-top:6px}
    .kpi .h{font-size:12px;color:var(--muted);line-height:1.45;margin-top:8px}
    .green{color:var(--bert)} .cyan{color:var(--bert2)} .warn{color:var(--warn)} .plum{color:var(--plum)} .bad{color:var(--bad)}
    .cards{display:grid;grid-template-columns:repeat(3,1fr);gap:14px} @media (max-width:1000px){.cards{grid-template-columns:1fr}}
    .card h3{margin:8px 0 8px;font-size:22px}
    .card .eyebrow{font-family:var(--mono);font-size:10px;letter-spacing:.18em;text-transform:uppercase;color:var(--bert)}
    table{width:100%;border-collapse:collapse} th,td{padding:13px 14px;text-align:left;font-size:13.5px;vertical-align:top}
    thead th{font-family:var(--mono);font-size:11px;letter-spacing:.16em;text-transform:uppercase;color:var(--muted2);border-bottom:1px solid var(--line);background:rgba(11,18,32,.5)}
    tbody tr:hover{background:rgba(55,255,139,.03)} tbody td{color:var(--muted);border-bottom:1px solid var(--line2)}
    .tablewrap{padding:0;overflow:hidden}
    .status{display:inline-block;padding:4px 9px;border-radius:6px;border:1px solid currentColor;font-family:var(--mono);font-size:10px;letter-spacing:.1em;text-transform:uppercase}
    .quote{margin-top:34px;border:1px solid rgba(55,255,139,.22);background:radial-gradient(700px 200px at 0% 0%, rgba(55,255,139,.10), transparent 60%),linear-gradient(180deg, rgba(11,18,32,.92), rgba(8,14,26,.88));border-radius:18px;padding:24px 26px}
    .quote .lbl{font-family:var(--mono);font-size:11px;color:var(--bert);letter-spacing:.22em;text-transform:uppercase}
    .quote .q{margin-top:12px;font-size:32px;line-height:1.25;font-weight:600;max-width:1000px}
    footer{margin-top:30px;padding-top:14px;border-top:1px dashed var(--line2);display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;font-family:var(--mono);font-size:11px;color:var(--muted2);letter-spacing:.08em}
    a{color:var(--bert2);text-decoration:none}
    """
end

function html_page(title::String, description::String, content::String; canonical::String)
    return """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>$(escape_html(title))</title>
      <meta name="description" content="$(escape_html(description))">
      <meta name="robots" content="index,follow">
      <meta property="og:title" content="$(escape_html(title))">
      <meta property="og:description" content="$(escape_html(description))">
      <meta property="og:type" content="website">
      <meta property="og:url" content="$(canonical)">
      <link rel="canonical" href="$(canonical)">
      <style>$(base_css())</style>
    </head>
    <body>
      <div class="grid-bg"></div>
      <div class="wrap">
        $(content)
      </div>
    </body>
    </html>
    """
end

status_badge(status::String) = "<span class=\"status $(status == "green" ? "green" : status == "yellow" ? "warn" : "bad")\">$(uppercase(status))</span>"

function overview_content(result::Dict)
    segment_rows = join([
        """
        <tr>
          <td><b>$(escape_html(item["label"]))</b><br><span class="section-note">$(escape_html(item["id"])) · $(escape_html(item["channel"]))</span></td>
          <td>$(item["send_cadence_days"]) days</td>
          <td>$(item["fatigue_index"])%</td>
          <td>$(item["stewardship_gap_days"]) days</td>
          <td>$(status_badge(item["status"]))</td>
        </tr>
        """ for item in result["segment_results"]
    ], "\n")

    channel_cards = join([
        """
        <div class="card">
          <div class="eyebrow">$(escape_html(item["id"]))</div>
          <h3>$(escape_html(item["label"]))</h3>
          <p>Weekly campaign capacity of <b>$(item["weekly_capacity"])</b> waves, stewardship buffer of <b>$(item["stewardship_buffer"]) days</b>, and reliability at $(item["reliability"])%.</p>
          <p>$(status_badge(item["status"]))</p>
        </div>
        """ for item in result["channel_results"]
    ], "\n")

    return """
    <div class="topbar">
      <div class="left">language atlas · julia nonprofit surface</div>
      <div class="right">
        <div>appeals.kineticgain.com</div>
        <div>generated $(escape_html(result["generated_on"])) · nonprofit / foundation ops</div>
      </div>
    </div>

    <div class="herorow">
      <section class="hero">
        <div class="chiprow">
          <span class="meta-chip">Julia fatigue modeling</span>
          <span class="meta-chip">donor cadence posture</span>
          <span class="meta-chip">nonprofit</span>
          <span class="meta-chip">stewardship ops</span>
        </div>
        <h1>See donor fatigue before the next appeal wave burns trust and suppresses response.</h1>
        <p>A Julia nonprofit operator surface for Kinetic Gain: score outreach cadence across donor segments, surface fatigue and stewardship risk, and publish a buyer-readable send posture from the same analysis core.</p>
        <div class="chiprow">
          <span class="pill">Route: /appeal-lane/</span>
          <span class="pill">Route: /fatigue-matrix/</span>
          <span class="pill">Route: /stewardship-posture/</span>
        </div>
      </section>
      <aside class="side">
        <div class="mini">
          <div class="lbl">safe-send coverage</div>
          <h3 class="green">$(result["coverage_pct"])%</h3>
          <p>Segments currently safe to move forward without an immediate fatigue pause.</p>
        </div>
        <div class="mini">
          <div class="lbl">high fatigue</div>
          <h3 class="bad">$(result["high_fatigue_segments"])</h3>
          <p>Audience segments that should pause direct asks before the next appeal wave.</p>
        </div>
        <div class="mini">
          <div class="lbl">approval window</div>
          <h3 class="cyan">$(result["approval_window_days"])d</h3>
          <p>Modeled review window before the next send-safe decision is expected.</p>
        </div>
      </aside>
    </div>

    <section class="section">
      <div class="sh"><h2>Operator KPIs</h2><div class="note">dashboard summary</div></div>
      <div class="kpis">
        <div class="kpi"><div class="v bad">$(result["blocked_waves"])</div><div class="lbl">blocked waves</div><div class="h">Segments that should pause outreach instead of sending another appeal.</div></div>
        <div class="kpi"><div class="v warn">$(result["review_segments"])</div><div class="lbl">needs review</div><div class="h">Segments that need stewardship review before another ask is approved.</div></div>
        <div class="kpi"><div class="v green">$(result["safe_send_segments"])</div><div class="lbl">safe send segments</div><div class="h">Segments still within cadence and stewardship guardrails.</div></div>
        <div class="kpi"><div class="v plum">$(length(result["channel_results"]))</div><div class="lbl">channels</div><div class="h">Outreach channels represented in the fatigue review surface.</div></div>
      </div>
    </section>

    <section class="section">
      <div class="sh"><h2>Channel posture</h2><div class="note">where cadence is getting tight</div></div>
      <div class="cards">
        $(channel_cards)
      </div>
    </section>

    <section class="section">
      <div class="sh"><h2>Appeal fatigue matrix</h2><div class="note">cadence vs stewardship</div></div>
      <div class="tablewrap">
        <table>
          <thead>
            <tr>
              <th>Segment</th>
              <th>Cadence</th>
              <th>Fatigue</th>
              <th>Gap</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            $(segment_rows)
          </tbody>
        </table>
      </div>
    </section>

    <section class="quote">
      <div class="lbl">Why this monetizes</div>
      <div class="q">Appeal fatigue is where nonprofit trust leaks first. A buyer-readable control plane for cadence, stewardship spacing, and send approvals turns vague “donor burnout” into an operator surface.</div>
    </section>

    <footer>
      <div>campaign-appeal-fatigue-monitor · synthetic outreach sample data only</div>
      <div><a href="https://github.com/mizcausevic-dev/">GitHub</a> · <a href="https://www.linkedin.com/in/mirzacausevic/">LinkedIn</a> · <a href="https://kineticgain.com/">Kinetic Gain</a></div>
      <div>routes: / · /appeal-lane · /fatigue-matrix · /stewardship-posture · /verification · /docs</div>
    </footer>
    """
end

function lane_content(result::Dict)
    rows = join([
        """
        <tr>
          <td><b>$(escape_html(item["label"]))</b><br><span class="section-note">$(escape_html(item["id"])) · $(escape_html(item["channel"]))</span></td>
          <td>$(item["households"])</td>
          <td>$(item["response_decay"])%</td>
          <td>$(item["recommended_action"])</td>
          <td>$(status_badge(item["status"]))</td>
        </tr>
        """ for item in result["segment_results"]
    ], "\n")

    return html_page(
        "Campaign Appeal Fatigue Monitor — Appeal Lane",
        "Review donor segments, cadence, and fatigue signals before another appeal wave goes out.",
        """
        <div class="topbar"><div class="left">appeal lane</div><div class="right">nonprofit / foundation ops</div></div>
        <section class="section">
          <div class="sh"><h2>Appeal lane</h2><div class="note">segment · action · status</div></div>
          <div class="tablewrap">
            <table>
              <thead><tr><th>Segment</th><th>Households</th><th>Decay</th><th>Action</th><th>Status</th></tr></thead>
              <tbody>
                $(rows)
              </tbody>
            </table>
          </div>
        </section>
        <footer><div>campaign-appeal-fatigue-monitor</div><div><a href="https://github.com/mizcausevic-dev/">GitHub</a> · <a href="https://www.linkedin.com/in/mirzacausevic/">LinkedIn</a> · <a href="https://kineticgain.com/">Kinetic Gain</a></div><div>/appeal-lane</div></footer>
        """;
        canonical = "https://appeals.kineticgain.com/appeal-lane/"
    )
end

function fatigue_content(result::Dict)
    rows = join([
        """
        <tr>
          <td><b>$(escape_html(item["label"]))</b></td>
          <td>$(item["send_cadence_days"]) days</td>
          <td>$(item["fatigue_index"])%</td>
          <td>$(item["stewardship_gap_days"]) days</td>
          <td>$(status_badge(item["status"]))</td>
        </tr>
        """ for item in result["segment_results"]
    ], "\n")

    return html_page(
        "Campaign Appeal Fatigue Monitor — Fatigue Matrix",
        "Trace donor cadence and fatigue levels across nonprofit campaign segments.",
        """
        <div class="topbar"><div class="left">fatigue matrix</div><div class="right">julia scoring core</div></div>
        <section class="section">
          <div class="sh"><h2>Fatigue matrix</h2><div class="note">cadence · fatigue · gap</div></div>
          <div class="tablewrap">
            <table>
              <thead><tr><th>Segment</th><th>Cadence</th><th>Fatigue</th><th>Stewardship Gap</th><th>Status</th></tr></thead>
              <tbody>
                $(rows)
              </tbody>
            </table>
          </div>
        </section>
        <footer><div>campaign-appeal-fatigue-monitor</div><div><a href="https://github.com/mizcausevic-dev/">GitHub</a> · <a href="https://www.linkedin.com/in/mirzacausevic/">LinkedIn</a> · <a href="https://kineticgain.com/">Kinetic Gain</a></div><div>/fatigue-matrix</div></footer>
        """;
        canonical = "https://appeals.kineticgain.com/fatigue-matrix/"
    )
end

function posture_content(result::Dict)
    cards = join([
        """
        <div class="card">
          <div class="eyebrow">$(escape_html(item["id"]))</div>
          <h3>$(escape_html(item["label"]))</h3>
          <p>$(item["segments"]) segments attached, $(item["red_segments"]) currently red, reliability $(item["reliability"])%, and stewardship buffer $(item["stewardship_buffer"]) days.</p>
          <p>$(status_badge(item["status"]))</p>
        </div>
        """ for item in result["channel_results"]
    ], "\n")

    return html_page(
        "Campaign Appeal Fatigue Monitor — Stewardship Posture",
        "Review channel-level stewardship posture before the next nonprofit send window.",
        """
        <div class="topbar"><div class="left">stewardship posture</div><div class="right">channel guardrails</div></div>
        <section class="section">
          <div class="sh"><h2>Stewardship posture</h2><div class="note">channel-level readiness</div></div>
          <div class="cards">
            $(cards)
          </div>
        </section>
        <footer><div>campaign-appeal-fatigue-monitor</div><div><a href="https://github.com/mizcausevic-dev/">GitHub</a> · <a href="https://www.linkedin.com/in/mirzacausevic/">LinkedIn</a> · <a href="https://kineticgain.com/">Kinetic Gain</a></div><div>/stewardship-posture</div></footer>
        """;
        canonical = "https://appeals.kineticgain.com/stewardship-posture/"
    )
end

function verification_content()
    return html_page(
        "Campaign Appeal Fatigue Monitor — Verification",
        "Verification notes for the synthetic nonprofit outreach proof surface.",
        """
        <div class="topbar"><div class="left">verification</div><div class="right">operator-safe claims only</div></div>
        <section class="section">
          <div class="sh"><h2>Verification</h2><div class="note">what this is and is not</div></div>
          <div class="cards">
            <div class="card"><div class="eyebrow">sample data</div><h3>Synthetic outreach records only</h3><p>No live donor records, no real fundraising platform credentials, and no production send schedules are published here.</p></div>
            <div class="card"><div class="eyebrow">modeled pressure</div><h3>Real nonprofit workflow shape</h3><p>The surface is grounded in cadence, fatigue, stewardship spacing, and send-safe review posture.</p></div>
            <div class="card"><div class="eyebrow">commercial framing</div><h3>No compliance overclaiming</h3><p>This is an operator proof surface and commercialization wedge, not a donor privacy or fundraising compliance certification claim.</p></div>
          </div>
        </section>
        <footer><div>campaign-appeal-fatigue-monitor</div><div><a href="https://github.com/mizcausevic-dev/">GitHub</a> · <a href="https://www.linkedin.com/in/mirzacausevic/">LinkedIn</a> · <a href="https://kineticgain.com/">Kinetic Gain</a></div><div>/verification</div></footer>
        """;
        canonical = "https://appeals.kineticgain.com/verification/"
    )
end

function docs_content()
    return html_page(
        "Campaign Appeal Fatigue Monitor — Docs",
        "Routes and API surfaces for the nonprofit appeal fatigue proof site.",
        """
        <div class="topbar"><div class="left">docs</div><div class="right">routes and api</div></div>
        <section class="section">
          <div class="sh"><h2>Docs</h2><div class="note">public surface</div></div>
          <div class="cards">
            <div class="card"><div class="eyebrow">routes</div><h3>Public pages</h3><p><code>/</code>, <code>/appeal-lane/</code>, <code>/fatigue-matrix/</code>, <code>/stewardship-posture/</code>, <code>/verification/</code>, <code>/docs/</code></p></div>
            <div class="card"><div class="eyebrow">api</div><h3>Structured payloads</h3><p><code>/api/dashboard.json</code>, <code>/api/segments.json</code>, <code>/api/channels.json</code></p></div>
            <div class="card"><div class="eyebrow">runtime</div><h3>Local commands</h3><p><code>julia --project=. scripts/run_demo.jl</code> and <code>julia --project=. scripts/generate_site.jl</code></p></div>
          </div>
        </section>
        <footer><div>campaign-appeal-fatigue-monitor</div><div><a href="https://github.com/mizcausevic-dev/">GitHub</a> · <a href="https://www.linkedin.com/in/mirzacausevic/">LinkedIn</a> · <a href="https://kineticgain.com/">Kinetic Gain</a></div><div>/docs</div></footer>
        """;
        canonical = "https://appeals.kineticgain.com/docs/"
    )
end

function write_site(result::Dict)
    root = joinpath(dirname(@__DIR__), "site")
    mkpath(root)
    mkpath(joinpath(root, "appeal-lane"))
    mkpath(joinpath(root, "fatigue-matrix"))
    mkpath(joinpath(root, "stewardship-posture"))
    mkpath(joinpath(root, "verification"))
    mkpath(joinpath(root, "docs"))
    mkpath(joinpath(root, "api"))

    write(joinpath(root, "index.html"), html_page(
        "Campaign Appeal Fatigue Monitor · Kinetic Gain",
        "Nonprofit operator surface for donor appeal cadence, fatigue, stewardship spacing, and send-safe posture.",
        overview_content(result);
        canonical = "https://appeals.kineticgain.com/"
    ))
    write(joinpath(root, "appeal-lane", "index.html"), lane_content(result))
    write(joinpath(root, "fatigue-matrix", "index.html"), fatigue_content(result))
    write(joinpath(root, "stewardship-posture", "index.html"), posture_content(result))
    write(joinpath(root, "verification", "index.html"), verification_content())
    write(joinpath(root, "docs", "index.html"), docs_content())

    write(joinpath(root, "api", "dashboard.json"), json_string(result))
    write(joinpath(root, "api", "segments.json"), json_string(result["segment_results"]))
    write(joinpath(root, "api", "channels.json"), json_string(result["channel_results"]))

    write(joinpath(root, "robots.txt"), "User-agent: *\nAllow: /\nSitemap: https://appeals.kineticgain.com/sitemap.xml\n")
    write(joinpath(root, "sitemap.xml"), """
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://appeals.kineticgain.com/</loc></url>
  <url><loc>https://appeals.kineticgain.com/appeal-lane/</loc></url>
  <url><loc>https://appeals.kineticgain.com/fatigue-matrix/</loc></url>
  <url><loc>https://appeals.kineticgain.com/stewardship-posture/</loc></url>
  <url><loc>https://appeals.kineticgain.com/verification/</loc></url>
  <url><loc>https://appeals.kineticgain.com/docs/</loc></url>
</urlset>
""")
    write(joinpath(root, "CNAME"), "appeals.kineticgain.com\n")
    return root
end

end
