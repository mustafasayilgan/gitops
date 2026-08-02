#!/bin/bash
set -euo pipefail

CPUS="${MINIKUBE_CPUS:-2}"
MEMORY="${MINIKUBE_MEMORY:-4096}"

HOSTS_DOMAINS=(
  hepapi.test
  dev.hepapi.test
  grafana.hepapi.test
  argo.hepapi.test
)

print_hosts() {
  echo "# on docker/colima drivers, minikube ip is often unreachable from macOS."
  echo "# Prefer 127.0.0.1 + 'sudo minikube tunnel' (see: ./scripts/minikube.sh tunnel)"
  echo
  echo "# add to /etc/hosts (sudo vim /etc/hosts)"
  for d in "${HOSTS_DOMAINS[@]}"; do
    echo "127.0.0.1 ${d}"
  done
}

ensure_ingress_lb() {
  # tunnel only exposes loadbalancer services; nodeport alone won't bind :80 on localhost
  kubectl -n ingress-nginx patch svc ingress-nginx-controller \
    -p '{"spec":{"type":"LoadBalancer"}}' >/dev/null
  echo "ingress-nginx-controller set to LoadBalancer"
}

if [ "${1:-}" = "install" ]; then
  # macOS via homebrew; for other operating systems, see: https://minikube.sigs.k8s.io/docs/start/
  brew install minikube
elif [ "${1:-}" = "start" ]; then
  minikube start --cpus="${CPUS}" --memory="${MEMORY}" --disk-size=20g
  minikube addons enable ingress || true
  ensure_ingress_lb || true
elif [ "${1:-}" = "stop" ]; then
  minikube stop
elif [ "${1:-}" = "delete" ]; then
  minikube delete
elif [ "${1:-}" = "status" ]; then
  minikube status
  kubectl get nodes
  kubectl get ingress -A
  kubectl -n ingress-nginx get svc ingress-nginx-controller
elif [ "${1:-}" = "hosts" ]; then
  print_hosts
elif [ "${1:-}" = "tunnel" ]; then
  ensure_ingress_lb
  echo "starting tunnel (keep this terminal open). Then open your domains in the browser."
  echo "hosts should point at 127.0.0.1 — run: ./scripts/minikube.sh hosts"
  sudo minikube tunnel
elif [ "${1:-}" = "get-hepapi-prod" ]; then
  kubectl get pods,svc,ingress -n prod
elif [ "${1:-}" = "get-hepapi-dev" ]; then
  kubectl get pods,svc,ingress -n dev
else
  echo "usage: $(basename "$0") {install|start|stop|delete|status|hosts|tunnel|get-hepapi-prod|get-hepapi-dev}"
  echo "env: MINIKUBE_CPUS (default ${CPUS}), MINIKUBE_MEMORY (default ${MEMORY})"
  exit 1
fi
