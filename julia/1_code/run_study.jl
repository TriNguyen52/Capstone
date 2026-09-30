include("solveMotion.jl")

using CSV
using DataFrames

const BASE_RADIUS = 2.38
const BASE_TENSION = 107.0
const BASE_VELOCITY = -0.6312
const BASE_DENSITY = 3.25
const BASE_MASS = BASE_DENSITY * 4pi * BASE_RADIUS^3 / 3
const BASE_DOMAIN = 52.5 / BASE_RADIUS

cases = [
    # Numerical convergence
    (group="resolution", label="N25", args=(N=25,)),
    (group="resolution", label="N50", args=(N=50,)),
    (group="resolution", label="N75", args=(N=75,)),
    (group="resolution", label="N100", args=(N=100,)),

    # Physical parameter sweeps at moderate resolution
    (group="velocity", label="v0.10", args=(N=50, v_k=-0.10)),
    (group="velocity", label="v0.30", args=(N=50, v_k=-0.30)),
    (group="velocity", label="v1.00", args=(N=50, v_k=-1.00)),
    (group="velocity", label="v2.00", args=(N=50, v_k=-2.00)),

    (group="tension", label="T25", args=(N=50, Tm=25.0)),
    (group="tension", label="T50", args=(N=50, Tm=50.0)),
    (group="tension", label="T200", args=(N=50, Tm=200.0)),
    (group="tension", label="T500", args=(N=50, Tm=500.0)),

    (group="mass", label="mass0.25x", args=(N=50, mS=0.25BASE_MASS)),
    (group="mass", label="mass4x", args=(N=50, mS=4BASE_MASS)),

    (group="radius", label="r1.0", args=(N=50, rS=1.0)),
    (group="radius", label="r5.0", args=(N=50, rS=5.0)),

    (group="domain", label="Rf8", args=(N=50, R_f=8.0)),
    (group="domain", label="Rf12", args=(N=50, R_f=12.0)),
    (group="domain", label="Rf35", args=(N=50, R_f=35.0)),
]

if !isempty(ARGS)
    cases = filter(case -> case.label in ARGS, cases)
end

results_path = isempty(ARGS) ? "study_results.csv" : "study_retry_results.csv"

results = DataFrame(
    group=String[], label=String[], status=String[], runtime_seconds=Float64[],
    contact_time_ms=Float64[], max_deflection_mm=Float64[], energy_ratio=Float64[],
    restitution=Float64[], final_dt_ms=Float64[], dr_mm=Float64[], error=String[],
)

for (index, case) in enumerate(cases)
    println("[$index/$(length(cases))] $(case.group): $(case.label)")
    started = time()
    try
        summary = redirect_stdout(devnull) do
            solveMotion(; plotter=false, export_data=false, case.args...)
        end
        push!(results, (
            case.group, case.label, "ok", time() - started,
            summary.contact_time, summary.maximum_deflection,
            summary.coef_of_restitution, sqrt(max(summary.coef_of_restitution, 0.0)),
            summary.final_dt, summary.dr, "",
        ))
    catch exception
        push!(results, (
            case.group, case.label, "failed", time() - started,
            NaN, NaN, NaN, NaN, NaN, NaN,
            sprint(showerror, exception),
        ))
    end
    CSV.write(results_path, results)
end

println(results)
