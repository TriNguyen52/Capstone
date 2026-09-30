include("solveMotion.jl")

using CSV
using DataFrames

const BASE_RADIUS = 2.38
const BASE_DENSITY = 3.25
const BASE_MASS = BASE_DENSITY * 4pi * BASE_RADIUS^3 / 3

cases = [
    (label="slow", args=(N=50, v_k=-0.30, simul_time=120.0)),
    (label="baseline", args=(N=50, v_k=-0.6312, simul_time=150.0)),
    (label="fast", args=(N=50, v_k=-1.00, simul_time=180.0)),
    (label="heavy", args=(N=50, v_k=-0.6312, mS=4BASE_MASS, simul_time=180.0)),
]

results = DataFrame(
    case=String[], status=String[], runtime_seconds=Float64[], event_count=Int[],
    start_times_ms=String[], end_times_ms=String[], impact_velocities=String[],
    separation_velocities=String[], max_contact_points=String[], error=String[],
)

format_values(values) = join(round.(values, digits=6), ";")

for (index, case) in enumerate(cases)
    println("[$index/$(length(cases))] $(case.label)")
    started = time()
    try
        summary = redirect_stdout(devnull) do
            solveMotion(;
                plotter=false,
                export_data=false,
                save_after_contact=true,
                case.args...,
            )
        end
        push!(results, (
            case.label, "ok", time() - started, length(summary.contact_start_times),
            format_values(summary.contact_start_times),
            format_values(summary.contact_end_times),
            format_values(summary.contact_start_velocities),
            format_values(summary.contact_end_velocities),
            join(summary.event_max_contact_points, ";"), "",
        ))
    catch exception
        push!(results, (
            case.label, "failed", time() - started, 0,
            "", "", "", "", "", sprint(showerror, exception),
        ))
    end
    CSV.write("rebound_results.csv", results)
end

println(results)
