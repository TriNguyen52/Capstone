include("solveMotion.jl")

using CSV
using DataFrames
using Plots
using Printf

const RADIUS = 2.38
const TENSION = 107.0
const MEMBRANE_DENSITY = 0.3
const MEMBRANE_RADIUS = 52.5
const WAVE_SPEED = sqrt(TENSION / MEMBRANE_DENSITY)
const TIME_UNIT = RADIUS / WAVE_SPEED
const WAVE_ROUND_TRIP = 2MEMBRANE_RADIUS / WAVE_SPEED
const DOMAIN_RATIO = MEMBRANE_RADIUS / RADIUS

const REGIME_CODES = Dict(
    "no contact" => 1,
    "no rebound" => 2,
    "single contact" => 3,
    "multiple bounces" => 4,
    "double contact" => 5,
    "chatter" => 6,
    "energy recovery" => 7,
)
const REGIME_LABELS = [
    "no contact", "no rebound", "single contact", "multiple bounces",
    "double contact", "chatter", "energy recovery",
]

function configuration(mode::String)
    if mode == "smoke"
        return (
            U_values=collect(range(0.015, 0.04, length=2)),
            M_values=10 .^ collect(range(log10(0.006), log10(0.015), length=2)),
            N=25,
            simul_time=120.0,
        )
    elseif mode == "pilot"
        return (
            U_values=collect(range(0.005, 0.08, length=10)),
            M_values=10 .^ collect(range(log10(0.003), log10(0.03), length=10)),
            N=25,
            simul_time=250.0,
        )
    elseif mode == "energy"
        return (
            U_values=[0.01, 0.02, 0.03, 0.045, 0.06],
            M_values=[0.004, 0.007, 0.012, 0.02],
            N=25,
            simul_time=180.0,
        )
    elseif mode == "full"
        return (
            U_values=collect(range(0.005, 0.08, length=20)),
            M_values=10 .^ collect(range(log10(0.003), log10(0.03), length=20)),
            N=50,
            simul_time=300.0,
        )
    end
    error("Unknown mode '$mode'. Use smoke, pilot, or full.")
end

empty_case_results() = DataFrame(
    case_id=String[], mode=String[], U=Float64[], M=Float64[],
    impact_speed=Float64[], sphere_mass=Float64[], status=String[],
    runtime_seconds=Float64[], event_count=Int[], completed_events=Int[],
    short_contacts=Int[], membrane_catches=Int[], energy_recovery_events=Int[],
    maximum_later_restitution=Float64[], regime=String[], error=String[],
)

empty_event_results() = DataFrame(
    case_id=String[], U=Float64[], M=Float64[], event_index=Int[],
    start_time_ms=Float64[], end_time_ms=Float64[], duration_ms=Float64[],
    preceding_flight_ms=Float64[], impact_velocity=Float64[],
    separation_velocity=Float64[], event_restitution=Float64[],
    membrane_position_before_impact=Float64[],
    membrane_velocity_before_impact=Float64[], approximate_phase=Float64[],
    sphere_position_at_impact=Float64[], sphere_position_at_separation=Float64[],
    total_membrane_kinetic=Float64[], total_membrane_elastic=Float64[],
    local_membrane_kinetic=Float64[], local_membrane_elastic=Float64[],
    outward_energy_flux=Float64[], maximum_contact_points=Int[], event_type=String[],
)

case_key(U, M) = @sprintf("U%.8g_M%.8g", U, M)

function classify_case(summary)
    starts = summary.contact_start_times
    ends = summary.contact_end_times
    vin = summary.contact_start_velocities
    vout = summary.contact_end_velocities
    completed = min(length(starts), length(ends))

    gaps = Float64[]
    for index in 2:length(starts)
        if index - 1 <= length(ends)
            push!(gaps, starts[index] - ends[index - 1])
        end
    end
    short_contacts = count(gap -> 0 <= gap < WAVE_ROUND_TRIP, gaps)
    membrane_catches = count(velocity -> velocity >= 0, vin[2:end])

    later_restitution = Float64[]
    for index in 2:completed
        if vin[index] < 0 && vout[index] > 0
            push!(later_restitution, abs(vout[index] / vin[index]))
        end
    end
    recovery_events = count(value -> value > 1.01, later_restitution)
    maximum_later_e = isempty(later_restitution) ? NaN : maximum(later_restitution)

    regime = if isempty(starts)
        "no contact"
    elseif isempty(ends)
        "no rebound"
    elseif recovery_events > 0
        "energy recovery"
    elseif short_contacts >= 2 || (membrane_catches > 0 && length(starts) >= 3)
        "chatter"
    elseif short_contacts == 1 || membrane_catches > 0
        "double contact"
    elseif length(starts) > 1
        "multiple bounces"
    else
        "single contact"
    end

    return (
        completed=completed,
        short_contacts=short_contacts,
        membrane_catches=membrane_catches,
        recovery_events=recovery_events,
        maximum_later_e=maximum_later_e,
        regime=regime,
    )
end

function append_events!(events::DataFrame, case_id::String, U::Float64, M::Float64, summary)
    starts = summary.contact_start_times
    ends = summary.contact_end_times
    vin = summary.contact_start_velocities
    vout = summary.contact_end_velocities

    for index in eachindex(starts)
        completed = index <= length(ends)
        end_time = completed ? ends[index] : NaN
        duration = completed ? end_time - starts[index] : NaN
        preceding_flight = index > 1 && index - 1 <= length(ends) ? starts[index] - ends[index - 1] : NaN
        separation_velocity = completed ? vout[index] : NaN
        event_e = completed && vin[index] < 0 && separation_velocity > 0 ? abs(separation_velocity / vin[index]) : NaN
        membrane_position = index <= length(summary.contact_start_membrane_positions) ? summary.contact_start_membrane_positions[index] : NaN
        membrane_velocity = index <= length(summary.contact_start_membrane_velocities) ? summary.contact_start_membrane_velocities[index] : NaN
        phase = mod(2pi * starts[index] / WAVE_ROUND_TRIP, 2pi)
        sphere_start = index <= length(summary.contact_start_sphere_positions) ? summary.contact_start_sphere_positions[index] : NaN
        sphere_end = index <= length(summary.contact_end_sphere_positions) ? summary.contact_end_sphere_positions[index] : NaN
        total_kinetic = index <= length(summary.contact_start_total_membrane_kinetic) ? summary.contact_start_total_membrane_kinetic[index] : NaN
        total_elastic = index <= length(summary.contact_start_total_membrane_elastic) ? summary.contact_start_total_membrane_elastic[index] : NaN
        local_kinetic = index <= length(summary.contact_start_local_membrane_kinetic) ? summary.contact_start_local_membrane_kinetic[index] : NaN
        local_elastic = index <= length(summary.contact_start_local_membrane_elastic) ? summary.contact_start_local_membrane_elastic[index] : NaN
        outward_flux = index <= length(summary.contact_start_outward_energy_flux) ? summary.contact_start_outward_energy_flux[index] : NaN
        maximum_cp = index <= length(summary.event_max_contact_points) ? summary.event_max_contact_points[index] : 0

        event_type = if index == 1
            "initial impact"
        elseif vin[index] >= 0
            "membrane catch"
        elseif isfinite(event_e) && event_e > 1.01
            "energy recovery"
        elseif isfinite(preceding_flight) && preceding_flight < WAVE_ROUND_TRIP
            "short recontact"
        else
            "full bounce"
        end

        push!(events, (
            case_id, U, M, index, starts[index], end_time, duration,
            preceding_flight, vin[index], separation_velocity, event_e,
            membrane_position, membrane_velocity, phase, sphere_start, sphere_end,
            total_kinetic, total_elastic, local_kinetic, local_elastic,
            outward_flux, maximum_cp, event_type,
        ))
    end
end

function make_plots(cases::DataFrame, events::DataFrame, config, output_directory::String)
    successful = filter(row -> row.status == "ok", cases)
    regime_matrix = fill(NaN, length(config.M_values), length(config.U_values))
    contacts_matrix = fill(NaN, size(regime_matrix))
    restitution_matrix = fill(NaN, size(regime_matrix))

    for row in eachrow(successful)
        ui = argmin(abs.(config.U_values .- row.U))
        mi = argmin(abs.(config.M_values .- row.M))
        regime_matrix[mi, ui] = REGIME_CODES[row.regime]
        contacts_matrix[mi, ui] = row.event_count
        restitution_matrix[mi, ui] = row.maximum_later_restitution
    end

    palette = cgrad([:gray75, :brown3, :steelblue, :seagreen3, :gold, :darkorange, :purple], categorical=true)
    regime_plot = heatmap(
        config.U_values, config.M_values, regime_matrix,
        xlabel="Dimensionless impact velocity, U", ylabel="Mass ratio, M",
        yscale=:log10, title="Contact regime map",
        color=palette, clims=(0.5, 7.5),
        colorbar=true, colorbar_ticks=(1:7, REGIME_LABELS), size=(1100, 650),
    )
    savefig(regime_plot, joinpath(output_directory, "regime_map.png"))

    count_plot = heatmap(
        config.U_values, config.M_values, contacts_matrix,
        xlabel="Dimensionless impact velocity, U", ylabel="Mass ratio, M",
        yscale=:log10, title="Number of contact events", color=:viridis,
        colorbar=true, colorbar_title="Events", size=(900, 650),
    )
    savefig(count_plot, joinpath(output_directory, "contact_count_map.png"))

    restitution_plot = heatmap(
        config.U_values, config.M_values, restitution_matrix,
        xlabel="Dimensionless impact velocity, U", ylabel="Mass ratio, M",
        yscale=:log10, title="Maximum restitution after first impact",
        color=:plasma, colorbar=true, colorbar_title="e", size=(900, 650),
    )
    savefig(restitution_plot, joinpath(output_directory, "energy_recovery_map.png"))

    phase_events = filter(row -> row.event_index > 1 && isfinite(row.event_restitution), events)
    if nrow(phase_events) > 0
        phase_plot = scatter(
            phase_events.membrane_velocity_before_impact,
            phase_events.event_restitution,
            marker_z=phase_events.U, color=:viridis,
            xlabel="Membrane-centre velocity before impact (m/s)",
            ylabel="Event restitution", title="Wave phase and energy return",
            colorbar_title="U", legend=false, size=(900, 650),
        )
        hline!(phase_plot, [1.0], linestyle=:dash, color=:black)
        savefig(phase_plot, joinpath(output_directory, "phase_vs_restitution.png"))
    end
end

function main(args)
mode = isempty(args) ? "pilot" : lowercase(args[1])
fresh = "fresh" in lowercase.(args)
config = configuration(mode)

if haskey(ENV, "REGIME_N")
    config = merge(config, (N=parse(Int, ENV["REGIME_N"]),))
end
if haskey(ENV, "REGIME_SIM_TIME")
    config = merge(config, (simul_time=parse(Float64, ENV["REGIME_SIM_TIME"]),))
end

root = normpath(joinpath(@__DIR__, "..", ".."))
output_directory = joinpath(root, "findings", "regime_map", mode)
mkpath(output_directory)
cases_path = joinpath(output_directory, "regime_cases.csv")
events_path = joinpath(output_directory, "regime_events.csv")

cases = !fresh && isfile(cases_path) ? CSV.read(cases_path, DataFrame) : empty_case_results()
events = !fresh && isfile(events_path) ? CSV.read(events_path, DataFrame) : empty_event_results()
completed_ids = Set(String.(cases.case_id))
total_cases = length(config.U_values) * length(config.M_values)
case_number = 0

println("Mode: $mode | N=$(config.N) | simulation time=$(config.simul_time) ms")
println("Wave speed=$(@sprintf("%.5f", WAVE_SPEED)) m/s | wave round trip=$(@sprintf("%.5f", WAVE_ROUND_TRIP)) ms")

for (mi, M) in enumerate(config.M_values), (ui, U) in enumerate(config.U_values)
    case_number += 1
    case_id = case_key(U, M)
    if case_id in completed_ids
        println("[$case_number/$total_cases] $case_id already complete")
        continue
    end

    impact_speed = U * WAVE_SPEED
    sphere_mass = MEMBRANE_DENSITY * RADIUS^2 / M
    println("[$case_number/$total_cases] $case_id | V=$(@sprintf("%.4f", impact_speed)) m/s | m=$(@sprintf("%.3f", sphere_mass)) mg")
    started = time()

    try
        summary = redirect_stdout(devnull) do
            solveMotion(
                rS=RADIUS,
                Tm=TENSION,
                mS=sphere_mass,
                v_k=-impact_speed,
                R_f=DOMAIN_RATIO,
                N=config.N,
                simul_time=config.simul_time,
                save_after_contact=true,
                plotter=false,
                export_data=false,
            )
        end
        classification = classify_case(summary)
        push!(cases, (
            case_id, mode, U, M, impact_speed, sphere_mass, "ok", time() - started,
            length(summary.contact_start_times), classification.completed,
            classification.short_contacts, classification.membrane_catches,
            classification.recovery_events, classification.maximum_later_e,
            classification.regime, "",
        ))
        append_events!(events, case_id, U, M, summary)
    catch exception
        push!(cases, (
            case_id, mode, U, M, impact_speed, sphere_mass, "failed", time() - started,
            0, 0, 0, 0, 0, NaN, "numerical failure", sprint(showerror, exception),
        ))
    end

    CSV.write(cases_path, cases)
    CSV.write(events_path, events)
    GC.gc()
end

make_plots(cases, events, config, output_directory)
println("Results written to $output_directory")
println(combine(groupby(cases, :regime), nrow => :cases))
end

main(ARGS)
