# FORMA eval report

Generated: 2026-09-09T18:00:44.464047 · fixtures: 17 · smoothing: true · **Gate 2: PASS** (precision ≥ 0.80, recall ≥ 0.70 per exercise)

| Exercise | Fixtures | Rep MAE | Cues/rep | Precision | Recall | F1 |
|---|---|---|---|---|---|---|
| glute_bridge | 2 | 0.00 | 0.22 | 100.0% | 100.0% | 100.0% |
| plank | 4 | 0.00 | 2.00 | 100.0% | 100.0% | 100.0% |
| push_up | 4 | 0.00 | 0.43 | 100.0% | 100.0% | 100.0% |
| bw_squat | 7 | 0.00 | 0.27 | 100.0% | 100.0% | 100.0% |

## Per rule

| Exercise | Rule | TP | FP | FN | Precision | Recall | F1 |
|---|---|---|---|---|---|---|---|
| glute_bridge | insufficient_extension | 4 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| plank | hip_sag | 1 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| plank | hip_pike | 1 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| plank | head_drop | 1 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| push_up | hip_sag | 3 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| push_up | hip_pike | 3 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| push_up | shallow_depth | 3 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| bw_squat | knee_valgus | 4 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| bw_squat | shallow_depth_front | 4 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| bw_squat | shallow_depth | 4 | 0 | 0 | 100.0% | 100.0% | 100.0% |
| bw_squat | torso_lean | 3 | 0 | 0 | 100.0% | 100.0% | 100.0% |

## Warnings

- syn_squat_side_lean_heels: label "heel_rise" is not evaluated for side (disabled rule, wrong view, or a typo) — those reps are unmeasured
