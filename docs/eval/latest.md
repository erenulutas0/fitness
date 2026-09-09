# FORMA eval report

Generated: 2026-09-09T03:03:10.886794 · fixtures: 12 · smoothing: true · **Gate 2: PASS** (precision ≥ 0.80, recall ≥ 0.70 per exercise)

| Exercise | Fixtures | Rep MAE | Cues/rep | Precision | Recall | F1 |
|---|---|---|---|---|---|---|
| glute_bridge | 2 | 0.00 | 0.22 | 100.0% | 100.0% | 100.0% |
| plank | 2 | 0.00 | 1.50 | 100.0% | 100.0% | 100.0% |
| push_up | 2 | 0.00 | 0.25 | 100.0% | 100.0% | 100.0% |
| bw_squat | 6 | 0.00 | 0.23 | 100.0% | 100.0% | 100.0% |

## Per rule

| Exercise | Rule | TP | FP | FN | Precision | Recall | F1 |
|---|---|---|---|---|---|---|---|
| glute_bridge | insufficient_extension | 4 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| plank | hip_sag | 1 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| plank | hip_pike | 0 | 0 | 0 | n/a | n/a | n/a |
| plank | head_drop | 0 | 0 | 0 | n/a | n/a | n/a |
| push_up | hip_sag | 3 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| push_up | hip_pike | 0 | 0 | 0 | n/a | n/a | n/a |
| push_up | shallow_depth | 0 | 0 | 0 | n/a | n/a | n/a |
| bw_squat | knee_valgus | 4 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| bw_squat | shallow_depth_front | 0 | 0 | 0 | n/a | n/a | n/a |
| bw_squat | shallow_depth | 4 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| bw_squat | torso_lean | 3 | 0 | 0 | 100.0% | 100.0% | 100.0% |

## Warnings

- syn_squat_side_lean_heels: label "heel_rise" is not evaluated for side (disabled rule, wrong view, or a typo) — those reps are unmeasured
