# GitHub metadata (paste into the repository settings)

**Description**
> A Helm chart for a game server on Kubernetes, and the two things a game server needs that a web API does not: a rollout that does not disconnect the matches in progress, and probes that tell a database blip apart from a dead pod.

**Topics**
kubernetes, helm, game-server, kind, hpa, poddisruptionbudget, probes, graceful-shutdown, prometheus

**Pinned blurb for the profile README**
> `k8s-game-server-charts` - rolling a game server out without dropping the matches in progress, verified on a kind cluster instead of asserted in a README.
