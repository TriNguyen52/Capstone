# Repeated-Rebound Simulation Report

## Method

Four extended Julia simulations used `N=50`, `save_after_contact=true`, and a duration long enough for the sphere to rise, fall, and contact the membrane again. A contact event was counted only when the contact-point count changed from zero to positive; growth of `CP` during one impact was not counted as another impact.

## Results

| Case | Initial speed (m/s) | Simulated time (ms) | Contact events | Event start times (ms) |
|---|---:|---:|---:|---|
| Slow | 0.3000 | 120 | 7 | 0.001, 40.790, 78.475, 84.580, 98.810, 105.610, 111.845 |
| Baseline | 0.6312 | 150 | 3 | 0.001, 79.685, 131.910 |
| Fast | 1.0000 | 180 | 2 | 0.000, 121.501 |
| Heavy (4× mass) | 0.6312 | 180 | 2 | 0.001, 125.489 |

### Baseline case

The three contact intervals were 0.001–3.440 ms, 79.685–86.660 ms, and 131.910–136.860 ms. Downward impact speeds were 0.6312, 0.3695, and 0.2259 m/s. Separation speeds were 0.3782, 0.2179, and 0.2476 m/s. The third separation was faster than the second despite a slower incoming sphere, showing that membrane vibration can return previously stored wave energy during a later collision.

### Slow case

The slow case produced seven contacts. After two ordinary rebounds, the third impact initiated several closely spaced contacts. The fourth event began with the sphere moving upward at 0.0656 m/s: the oscillating membrane caught the rising sphere from below. Later low-speed contacts form a contact-chatter regime controlled by the relative motion of the membrane and sphere rather than by a simple sequence of independent ballistic bounces.

### Fast and heavy cases

The fast sphere made its second contact at 121.501 ms, entering at 0.5764 m/s and leaving at 0.3385 m/s. The heavy sphere made its second contact at 125.489 ms, entering at 0.5760 m/s and leaving at 0.5510 m/s. Its first and second contact durations were both about 8.23 ms, substantially longer than the baseline contacts. The heavy sphere retained much more rebound speed.

## Interpretation

Repeated-contact timing is not determined by gravity alone. The sphere follows an approximately ballistic trajectory between impacts, while the membrane continues oscillating. A later collision depends on both the sphere position and the instantaneous membrane displacement and velocity. Consequently, later impacts can occur earlier than a rigid-surface estimate, the membrane can catch a sphere that is still moving upward, and rebound speed need not decrease monotonically from one event to the next.

These later events are also sensitive to the finite membrane radius. Waves can reflect from the fixed outer boundary many times before the second impact. Therefore, the reported times describe this model's default finite membrane, not an infinite membrane. Domain-size and resolution sweeps should be repeated before treating later-impact timing as a quantitative experimental prediction.

## Main finding

The simulations predict genuine multiple contacts in all four tested cases. Lower initial speed produced the most complex repeated-contact behavior, while fast and heavy spheres spent longer in ballistic flight before a second impact. The slow case demonstrates that the coupled membrane–sphere system cannot always be modeled as a ball bouncing from a passive stationary surface.
