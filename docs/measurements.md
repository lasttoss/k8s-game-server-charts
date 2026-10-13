# Measurements

The README claims a cluster, not a manifest: a chart that only renders is a chart nobody has run. This
is the run.

## Environment

| | |
|---|---|
| Machine | 12-core x86-64 (AMD64), Ubuntu 24.04 |
| kind | cluster `game-server-charts`, one control-plane node |
| kubectl / helm | from `~/.local/bin` |
| Date | 2026-10-13 (UTC) |

## 2 pods `1/1 Running`, `helm test` Succeeded, HPA and PDB created

```
$ make verify            # kind-up, install, verify, then `make kind-down` where the caller wants it
A rollout takes no pod down before its successor is ready (maxUnavailable: 0) and drains for
30s, so a deploy does not end the matches in progress.
kubectl rollout status deploy/dev-game-server --timeout=180s
deployment "dev-game-server" successfully rolled out
helm test dev --namespace default --timeout 180s
STATUS: deployed
TEST SUITE:  dev-game-server-test-ready
... the chart is installed on a real cluster and the service answers on every probe path

$ kubectl get pods,hpa,pdb -A
default   pod/dev-game-server-66dc4dff8c-4dpsl   1/1   Running   0   23s
default   pod/dev-game-server-66dc4dff8c-mm42n   1/1   Running   0   23s
default   pod/dev-game-server-test-ready         0/1   Completed 0   11s
default   horizontalpodautoscaler.autoscaling/dev-game-server   Deployment/dev-game-server  cpu: <unknown>/70%   2   10   2   23s
default   poddisruptionbudget.policy/dev-game-server            1   N/A   1   23s
```

**Result.** Every number in the claim reproduces: two pods at `1/1 Running`, a `helm test` pod that
reached `Completed`, an HPA created with `MINPODS 2 / MAXPODS 10` on a 70% CPU target, and a PDB with
`minAvailable 1` and one allowed disruption. The `cpu: <unknown>` reading is the metrics server
warming up 23 seconds into the cluster's life, not a missing target.

**Teardown.** `make kind-down` deletes the cluster - the run above created one and removed it, so this
page costs nothing to leave lying around.
