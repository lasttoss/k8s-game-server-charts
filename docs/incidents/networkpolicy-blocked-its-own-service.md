# The chart's NetworkPolicy blocked its own service

**Symptom.** After `helm upgrade --install`, the pods were `1/1 Running` and the kubelet's probes
answered `200` in 5µs, but `helm test` failed:

```
checking / through the service
wget: download timed out
```

**What it was not.** Not a timing problem: waiting fifteen seconds and testing again failed the same way,
and a second pod in the same namespace timed out too.

**What it was.** The NetworkPolicy. Two experiments in the order that halves the problem each time:

| Policy | `helm test` |
|---|---|
| ingress from the namespace's pods on port 8080, egress DNS only | Failed |
| ingress only, no egress rules | Succeeded |
| ingress, egress DNS **and** all pods | Succeeded |

So the ingress was fine and the egress policy was the culprit - specifically, the **return path**. A TCP
response is an egress packet from the pod that served the request. A CNI that tracks the inbound
connection (conntrack) lets it through as part of that connection; kindnet evaluates egress packets on
their own, so the SYN was allowed and the SYN-ACK was dropped. The client sees a connect that hangs, and
the only visible clue is that the kubelet - whose probe traffic is not governed by the policy - is happy.

**The fix.**

```yaml
egress:
  - to: [{namespaceSelector: {}, podSelector: {matchLabels: {k8s-app: kube-dns}}}]   # DNS
    ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]
  - to: [{podSelector: {}}]                                                        # the answers
    ports: [{port: 8080, protocol: TCP}]
```

**What would have caught it earlier.** Nothing in the chart: `helm lint --strict` and `helm template`
both passed, and every claim was true of the manifest. It took `helm test` on a real cluster, which is
why `make verify` installs the chart on kind and why CI does the same rather than only linting YAML.

**The general rule.** When an egress policy is added to a pod that serves traffic, the return path is
part of the policy. "Allow only what it initiates" is a rule about a client, not about a server.
