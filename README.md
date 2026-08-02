# Argo CD GitOps

Helm charts + Argo Applications for the Flask + MongoDB API.

App source / CI: [mustafasayilgan/pymongo](https://github.com/mustafasayilgan/pymongo)  
This repo: image tags in `values.yaml` → Argo syncs the cluster.

## Layout

```
apps/
  prod/     # hepapi + mongo (replicaCount: 1)
  dev/      # same chart shape (scaled to 0 for now)
manual/
  values.yaml                         # Argo CD Helm values
  values-kube-prometheus-stack.yaml   # optional monitoring
  argocd-projects.yaml
  application-prod.yaml
  application-dev.yaml
scripts/
  minikube.sh       # start / hosts / tunnel helpers
  load-test.sh      # hit the API for Grafana demos
```

## Prerequisites (minikube)

```sh
./scripts/minikube.sh start          # enables ingress addon when possible
minikube addons enable ingress       # if needed
./scripts/minikube.sh hosts          # print /etc/hosts lines
./scripts/minikube.sh tunnel         # keep running (Docker/Colima → 127.0.0.1)
```

`/etc/hosts`:

```
127.0.0.1 hepapi.test
127.0.0.1 dev.hepapi.test
127.0.0.1 grafana.hepapi.test
127.0.0.1 argo.hepapi.test
```

## Install Argo CD + apps

```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd \
  -n argocd --create-namespace -f manual/values.yaml

kubectl apply -f manual/argocd-projects.yaml
kubectl apply -f manual/application-prod.yaml
kubectl apply -f manual/application-dev.yaml
```

| Application   | Path       | Namespace |
|---------------|------------|-----------|
| `hepapi-prod` | `apps/prod`| `prod`    |
| `hepapi-dev`  | `apps/dev` | `dev`     |

UI: http://argo.hepapi.test

## Mongo Secret

Credentials are **not** stored in this repo. For local/minikube, a plain Kubernetes Secret via `kubectl` is enough. For real clusters, prefer Sealed Secrets, Sops, or a cloud secret manager.

Create before (or with) the first sync. Names/keys must match the charts (`hepapi-mongo` / `dev-hepapi-mongo`):

```sh
# prod
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic hepapi-mongo -n prod \
  --from-literal=MONGO_INITDB_ROOT_USERNAME=root \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD='CHANGE_ME' \
  --from-literal=MONGO_APP_USERNAME=hepapiuser \
  --from-literal=MONGO_APP_PASSWORD='CHANGE_ME' \
  --from-literal=MONGO_URL='mongodb://hepapiuser:CHANGE_ME@mongo:27017/hepapi?authSource=hepapi'

# dev (when you scale it up)
kubectl create secret generic dev-hepapi-mongo -n dev \
  --from-literal=MONGO_INITDB_ROOT_USERNAME=root \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD='CHANGE_ME' \
  --from-literal=MONGO_APP_USERNAME=hepapiuser \
  --from-literal=MONGO_APP_PASSWORD='CHANGE_ME' \
  --from-literal=MONGO_URL='mongodb://hepapiuser:CHANGE_ME@mongo:27017/hepapi?authSource=hepapi'
```

Mongo uses a PVC (`persistence.size` in values). Init user script runs only on an empty volume.

## Ingress / URLs

| Host                   | Service        |
|------------------------|----------------|
| http://hepapi.test     | app (prod) → redirects `/` to `/api/items` |
| http://dev.hepapi.test | app (dev, when replicas > 0) |
| http://argo.hepapi.test| Argo CD        |
| http://grafana.hepapi.test | Grafana    |

Health: http://hepapi.test/api/health

## CI → CD

Push to **main** in the app repo builds/pushes `user/hepapi:<sha>` and bumps `apps/prod/values.yaml` `image:`.  
Argo auto-syncs from `HEAD`. Dev image path is ready; chart stays at `replicaCount: 0` until you enable it.

## Optional: monitoring

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f manual/values-kube-prometheus-stack.yaml
```

Load traffic while watching Grafana:

```sh
./scripts/load-test.sh
```