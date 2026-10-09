# Where this comes from

Original work, written from scratch on personal time and personal equipment. No employer manifests,
values, hostnames, cluster names or secrets are in it: the demo target is a public image
(`hashicorp/http-echo`), the namespace is `default`, and the Secret the chart references is created by
`make kind-up` with a value that is a literal string in this repository.

The probe/rollout/PDB/HPA decisions come from running game servers in production: readiness separate from
liveness, `maxUnavailable: 0` for pods that hold matches, and a drain budget that matches what the server
actually needs on SIGTERM.
