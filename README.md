# campaign-appeal-fatigue-monitor

Julia operator surface for donor appeal saturation, segment fatigue, send cadence pressure, and stewardship-safe outreach posture.

## What it shows

- real Julia added to the public Kinetic Gain language atlas
- monetizable nonprofit audience analysis across donor segments, campaign waves, and stewardship windows
- buyer-readable operator reporting generated from the same fatigue scoring core

## Routes

- `/`
- `/appeal-lane/`
- `/fatigue-matrix/`
- `/stewardship-posture/`
- `/verification/`
- `/docs/`

## Local development

```powershell
& 'C:\Users\chaus\AppData\Local\Programs\Julia-1.12.6\bin\julia.exe' --project=. scripts\run_demo.jl
& 'C:\Users\chaus\AppData\Local\Programs\Julia-1.12.6\bin\julia.exe' --project=. scripts\generate_site.jl
```

## Validation

```powershell
& 'C:\Users\chaus\AppData\Local\Programs\Julia-1.12.6\bin\julia.exe' --project=. -e "using Pkg; Pkg.test()"
& 'C:\Users\chaus\AppData\Local\Programs\Julia-1.12.6\bin\julia.exe' --project=. scripts\smoke_check.jl
```

## Why this matters

Kinetic Gain Embedded tie-back:

This repo proves Kinetic Gain can ship auditable nonprofit outreach and stewardship logic in Julia, not just wrap dashboards around generic fundraising metrics. The language-atlas signal is real: score, verify, and publish the same operator surface from Julia code.

## Commercial path

- `Hosted preview planned`
- `Consulting hook`

This is the kind of surface that can ladder into donor outreach reviews, campaign guardrail templates, and embedded stewardship planning work for nonprofit and foundation teams.

---

Part of the [Kinetic Gain operator portfolio](https://kineticgain.com/) · docs: [suite.kineticgain.com](https://suite.kineticgain.com/) · live: [appeals.kineticgain.com](https://appeals.kineticgain.com/)
