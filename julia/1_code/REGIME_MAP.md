# Dimensionless Contact-Regime Map

`run_regime_map.jl` sweeps dimensionless impact velocity `U` and mass ratio `M`, follows repeated rebounds, classifies every case, checkpoints CSV results, and generates heatmaps.

## Commands

From `julia/1_code`:

```powershell
# Four-case workflow test
julia --project=.. run_regime_map.jl smoke fresh

# 10 × 10 exploratory map at N=25
julia --project=.. run_regime_map.jl pilot fresh

# 5 × 4 targeted energy-hypothesis study at N=25
julia --project=.. run_regime_map.jl energy fresh

# Resume an interrupted pilot map
julia --project=.. run_regime_map.jl pilot

# 20 × 20 map at N=50
julia --project=.. run_regime_map.jl full fresh
```

Optional environment overrides:

```powershell
$env:REGIME_N = "50"
$env:REGIME_SIM_TIME = "300"
julia --project=.. run_regime_map.jl pilot fresh
```

Results are stored under `findings/regime_map/<mode>/`:

- `regime_cases.csv`: one row per `(U,M)` simulation;
- `regime_events.csv`: one row per contact event;
- `regime_map.png`: dominant contact regime;
- `contact_count_map.png`: number of contact events;
- `energy_recovery_map.png`: maximum later-event restitution;
- `phase_vs_restitution.png`: pre-impact membrane velocity versus event restitution, when later completed events exist.

The classifier labels no contact, no rebound, single contact, multiple bounces, double contact, chatter, and energy recovery. A later event is marked as energy recovery only when its velocity restitution exceeds `1.01`. A flight shorter than one membrane wave round trip is provisionally treated as a short recontact.
