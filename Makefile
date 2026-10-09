CLUSTER := game-server-charts
RELEASE := dev
CHART   := charts/game-server
# The secret is never a value: the chart refuses to render without it (templates/secret.yaml), and this
# is the name it looks for. In a real cluster an ExternalSecret puts it there.
SET     := --set secret.existingSecret=game-server-secret

.PHONY: kind-up kind-down render guard install verify load uninstall

# A cluster that proves the chart, in a minute, on a laptop.
kind-up:
	kind create cluster --name $(CLUSTER) --wait 120s
	kubectl create secret generic game-server-secret --from-literal=server_key=local-demo --dry-run=client -o yaml | kubectl apply -f -

kind-down:
	kind delete cluster --name $(CLUSTER)

# `helm template` outside a cluster cannot look the secret up, so it says so instead of failing.
render:
	helm template $(RELEASE) $(CHART) $(SET) --set secret.allowMissing=true > /dev/null
	@echo "the chart renders"

# The guard is a feature, so it gets a test: a chart that quietly installs with no secret is a chart
# that leaks one, or one whose pods start empty.
guard:
	@if helm template $(RELEASE) $(CHART) > /dev/null 2>&1; then \
		echo "the chart rendered with no secret: the guard is broken"; exit 1; \
	fi
	@echo "the chart refuses to render without a secret"

install:
	helm upgrade --install $(RELEASE) $(CHART) --namespace default $(SET) --wait --timeout 180s

verify: kind-up install
	kubectl rollout status deploy/$(RELEASE)-game-server --timeout=180s
	helm test $(RELEASE) --namespace default --timeout 180s
	kubectl get hpa,pdb,netpol -l app.kubernetes.io/instance=$(RELEASE)
	@echo "the chart is installed on a real cluster and the service answers on every probe path"

uninstall:
	helm uninstall $(RELEASE) --namespace default || true
