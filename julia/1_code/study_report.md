# Parameter Study: Rigid Sphere Impact on an Elastic Membrane

## Scope

Nineteen Julia simulations examined spatial resolution, impact velocity, membrane tension, sphere mass, sphere radius, and computational-domain radius. Unless varied, the defaults were a 2.38 mm sphere, membrane tension of 107, impact velocity of -0.6312 m/s, density of 3.25 mg/mm^3, and the default domain radius. Physical sweeps used `N=50`; the reference calculation used `N=100`.

## Reference result

The `N=100` calculation predicted a contact time of 3.4797 ms, maximum deflection of 0.6474 mm, returned-energy ratio of 0.3599, and conventional restitution estimate `e = 0.6000`.

## Main findings

### Numerical convergence

| N | Contact time (ms) | Maximum deflection (mm) | Restitution e |
|---:|---:|---:|---:|
| 25 | 3.3350 | 0.6014 | 0.5722 |
| 50 | 3.4488 | 0.6324 | 0.5917 |
| 75 | failed | failed | failed |
| 100 | 3.4797 | 0.6474 | 0.6000 |

Relative to `N=100`, `N=50` was low by about 0.9% in contact time, 2.3% in maximum deflection, and 1.4% in restitution. It is adequate for trend exploration, while `N=100` is preferable for reported values. `N=75` exposed a numerical edge case: sphere geometry evaluated `sqrt(-2.22e-16)` because of floating-point roundoff at the contact boundary. This is a code robustness issue, not a physical result.

### Impact velocity

| Impact speed (m/s) | Contact time (ms) | Maximum deflection (mm) | Restitution e |
|---:|---:|---:|---:|
| 0.10 | 3.8700 | 0.1171 | 0.5683 |
| 0.30 | 3.5375 | 0.3145 | 0.5965 |
| 0.6312 | 3.4488 | 0.6324 | 0.5917 |
| 1.00 | 3.3694 | 0.9702 | 0.5771 |
| 2.00 | 3.3098 | 1.8781 | 0.5579 |

Maximum deflection grew nearly linearly over this range. Contact time decreased moderately with speed. Restitution peaked near 0.3 m/s and then decreased, indicating that a larger fraction of energy remained in membrane motion at severe impact.

### Membrane tension

| Tension | Contact time (ms) | Maximum deflection (mm) | Restitution e |
|---:|---:|---:|---:|
| 25 | 7.0688 | 1.2899 | 0.5507 |
| 50 | 4.9988 | 0.9198 | 0.5747 |
| 107 | 3.4488 | 0.6324 | 0.5917 |
| 200 | 2.5188 | 0.4612 | 0.5980 |
| 500 | 1.6188 | 0.2941 | 0.6074 |

Both contact time and deflection decreased approximately with the inverse square root of tension. Stiffer membranes also returned a slightly larger fraction of the sphere's speed.

### Sphere mass

| Mass relative to baseline | Contact time (ms) | Maximum deflection (mm) | Restitution e |
|---:|---:|---:|---:|
| 0.25× | 1.6488 | 0.2901 | 0.5580 |
| 1× | 3.4488 | 0.6324 | 0.5917 |
| 4× | 8.2388 | 1.3954 | 0.9152 |

Heavier spheres produced much longer contact and deeper deformation. The very high restitution for the 4× case should be checked using a larger domain because its long contact gives boundary-reflected waves more time to return.

### Domain-size sensitivity

| Domain radius, R_f | Contact time (ms) | Maximum deflection (mm) | Restitution e |
|---:|---:|---:|---:|
| 8 | 3.4438 | 0.6320 | 0.9452 |
| 12 | 4.0988 | 0.6324 | 0.8067 |
| 22.06 (default) | 3.4488 | 0.6324 | 0.5917 |
| 35 | 3.4488 | 0.6324 | 0.5917 |

`R_f=35` reproduced the default result, while small domains greatly inflated rebound. Maximum compression barely changed, but reflected waves returned during unloading and supplied energy back to the sphere. A domain-convergence check is therefore essential whenever contact is long or the sphere is heavy.

### Radius edge cases

At `rS=1.0 mm`, the solver reported an energy ratio of 14.31 (`e=3.78`), which violates passive energy conservation and must be rejected as numerical/model breakdown. The final timestep collapsed to 0.000156 ms. At `rS=5.0 mm`, it predicted 10.48 ms contact, 2.09 mm deflection, and `e=0.95`; this should also be repeated with larger domains and finer grids before being treated as physical.

## Conclusions

The most reliable trends are that increasing impact speed increases deflection and modestly shortens contact, increasing membrane tension strongly shortens contact and reduces deflection, and increasing sphere mass lengthens contact and increases deformation. The study also shows that energy-based results are much more sensitive to domain size than maximum deflection. Future studies should use at least `N=100` for final values, verify domain independence, reject any energy ratio above one, and clamp tiny negative roundoff inside the sphere-geometry square root before using arbitrary resolutions such as `N=75`.
