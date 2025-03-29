set export
set shell := ["bash", "-uc"]
                                 
yaml          := justfile_directory() + "/yaml"
secrets       := justfile_directory() + "/secrets"
apps          := justfile_directory() + "/apps"
kind          := justfile_directory() + "/tf-kind"
vcluster      := justfile_directory() + "/vcluster-setup"
              
browse        := if os() == "linux" { "xdg-open "} else { "open" }
copy          := if os() == "linux" { "xsel -ib"} else { "pbcopy" }
replace       := if os() == "linux" { "sed -i"} else { "sed -i '' -e" }

export base64encoded_azure_creds    := `base64 ~/crossplane-azure-provider-key.json | tr -d "\n"`
              
argocd_port   := "30950"
                                 
# this list of available targets
# targets marked with * are main targets
default:
  just --list --unsorted

vcluster_setup: vcluster_create vcluster_setup_crossplane

vcluster_create:
  kubectl create namespace team2
  vcluster create team2-vcluster -n team2 -f {{vcluster}}/team2-vcluster-values.yaml --connect=false
  vcluster connect team2-vcluster

vcluster_setup_crossplane:
  vcluster connect team2-vcluster
  just setup_crossplane crossplane-system
  kubectl apply -f {{vcluster}}/team2-providers.yaml
  kubectl wait --for condition=healthy --timeout=300s provider.pkg --all
  kubectl apply -f {{vcluster}}/team2_provider-configs.yaml
  kubectl apply -f {{vcluster}}/team2_functions.yaml
  kubectl apply -f {{vcluster}}/team2-definition.yaml
  kubectl apply -f {{vcluster}}/team2-composition.yaml
  kubectl apply -f {{vcluster}}/team2-platform-demo-rg.yaml

vcluster_create_claim:
  vcluster connect team2-vcluster
  kubectl create namespace team2 --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f {{vcluster}}/team2-claim.yaml -n team2

# cleanup team2 demo
vcluster_cleanup_claim:
  vcluster connect team2-vcluster
  kubectl delete -f {{vcluster}}/team2-claim.yaml
  kubectl delete -f {{vcluster}}/team2-platform-demo-rg.yaml
  vcluster disconnect
  vcluster delete team2-vcluster -n team2
  kubectl delete namespace team2

# * setup kind cluster with crossplane, ArgoCD and launch argocd in browser
setup: setup_kind setup_crossplane setup_argo create_azure_secret create_providers bootstrap_apps deploy_monitoring

create_azure_secret:
  @envsubst < {{secrets}}/azure-provider-secret.yaml | kubectl apply -f - 

create_providers:
  envsubst < {{yaml}}/providers.yaml | kubectl apply -f - 
  kubectl wait --for condition=healthy --timeout=300s provider.pkg --all
  envsubst < {{yaml}}/provider-configs.yaml | kubectl apply -f -
  envsubst < {{yaml}}/functions.yaml | kubectl apply -f -
  just apply_composition

# render composition
render_composition:
  crossplane beta render ../apps-deployment/storage-reader/storage-reader-claim.yaml yaml/composition.yaml yaml/functions.yaml

# setup kind cluster
setup_kind:
  #!/usr/bin/env bash
  set -euo pipefail

  cd {{kind}} && terraform apply -auto-approve

# apply composition and definition
apply_composition:
  envsubst < {{yaml}}/composition.yaml | kubectl apply -f -
  envsubst < {{yaml}}/definition.yaml | kubectl apply -f -

# watch for claim application_crossplane_resources
watch_claim:
  watch crossplane beta trace appclaim.acmeplatform.com/platform-demo -n argocd

# setup universal crossplane
setup_crossplane xp_namespace='crossplane-system':
  #!/usr/bin/env bash
  if kubectl get namespace {{xp_namespace}} > /dev/null 2>&1; then
    echo "Namespace {{xp_namespace}} already exists"
  else
    echo "Creating namespace {{xp_namespace}}"
    kubectl create namespace {{xp_namespace}}
  fi

  echo "Installing crossplane version"
  helm repo add crossplane-stable https://charts.crossplane.io/stable
  helm repo update
  helm upgrade --install crossplane \
       --namespace {{xp_namespace}} crossplane-stable/crossplane \
       --set args='{"--enable-usages"}'
  kubectl wait --for condition=Available=True --timeout=300s deployment/crossplane --namespace {{xp_namespace}}

# setup ArgoCD and patch server service to nodePort 30950
setup_argo:
  #!/usr/bin/env bash
  echo "Installing ArgoCD"
  if kubectl get namespace argocd > /dev/null 2>&1; then
    echo "Namespace argocd already exists"
  else
    echo "Creating namespace argocd"
    kubectl create namespace argocd
  fi
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 
  kubectl wait --for condition=Available=True --timeout=300s deployment/argocd-server --namespace argocd
  kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
  kubectl patch svc argocd-server -n argocd --type merge --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/nodePort", "value": {{argocd_port}}}]'

# deploy monitoring stack, user: admin, pw: prom-operator
deploy_monitoring:
  kubectl apply -f {{yaml}}/grafana-dashboard.yaml
  @helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  @helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n prometheus \
   --set namespaceOverride=prometheus \
   --set prometheus.service.type=NodePort,prometheus.service.nodePort=32090 \
   --set grafana.service.type=NodePort,grafana.service.nodePort=32000 \
   --set grafana.namespaceOverride=prometheus \
   --set grafana.sidecar.dashboards.enabled=true \
   --set grafana.sidecar.dashboards.label="grafana_dashboard" \
   --set grafana.defaultDashboardsEnabled=true \
   --set kube-state-metrics.namespaceOverride=prometheus \
   --set prometheus-node-exporter.namespaceOverride=prometheus --create-namespace
  @kubectl -n prometheus patch prometheus kube-prometheus-stack-prometheus --type merge --patch '{"spec":{"enableAdminAPI":true}}'

# copy ArgoCD server secret to clipboard and launch browser, user admin, pw paste from clipboard
launch_argo:
  #!/usr/bin/env bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | {{copy}}
  sleep 3
  nohup {{browse}} http://localhost:{{argocd_port}} >/dev/null 2>&1 &

# bootstrap ArgoCD apps and set reconcilation timer to 30 seconds
bootstrap_apps:
  kubectl apply -f bootstrap.yaml

# sync apps locally
sync:
  #!/usr/bin/env bash
  export argo_pw=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  yes | argocd login localhost:{{argocd_port}} --username admin --password "${argo_pw}"
  argocd app sync bootstrap --prune --local ./apps 

# create PR for vCluster team2 infrastructure in apps-deployment repo
setup_vcluster_pr:
  #!/usr/bin/env bash
  set -euo pipefail
  
  # Apply the ArgoCD application that will watch the vcluster-team2 directory
  kubectl apply -f demo-resources/vcluster-app.yaml
  
  # Clone the apps-deployment repository to a temporary directory
  rm -rf /tmp/apps-deployment
  git clone https://github.com/Piotr1215/apps-deployment /tmp/apps-deployment
  cd /tmp/apps-deployment
  
  # Create a new branch
  git checkout -b add-vcluster-team2
  
  # Create the vcluster-team2 directory
  mkdir -p vcluster-team2
  
  # Copy the vCluster files
  cp -R {{vcluster}}/*.yaml vcluster-team2/
  
  # Remove the values file (will be configured via Helm)
  rm -f vcluster-team2/team2-vcluster-values.yaml
  
  # Add vCluster Helm release manifest
  cat > vcluster-team2/vcluster.yaml << 'EOL'
apiVersion: v1
kind: Namespace
metadata:
  name: team2
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: team2-vcluster
  namespace: team2
spec:
  interval: 5m
  chart:
    spec:
      chart: vcluster
      version: "0.15.0"
      sourceRef:
        kind: HelmRepository
        name: loft
        namespace: argocd
  values:
    sync:
      fromHost:
        secrets:
          enabled: true
          mappings:
            byName:
              "crossplane-system/azure-creds": "crossplane-system/azure-creds"
        ingressClasses:
          enabled: true
      toHost:
        ingresses:
          enabled: true
EOL

  # Add HelmRepository
  cat > vcluster-team2/helm-repo.yaml << 'EOL'
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: loft
  namespace: argocd
spec:
  interval: 1h
  url: https://charts.loft.sh
EOL

  # Add and commit changes
  git add vcluster-team2/
  git commit -m "Add vCluster setup for Team2"
  
  # Push and create PR
  git push -u origin add-vcluster-team2
  gh pr create --title "Add vCluster setup for Team2" --body "This PR adds the vCluster infrastructure setup for Team2 using vCluster and Crossplane."

# create PR for team2 claim in apps-deployment repo
setup_team2_claim_pr:
  #!/usr/bin/env bash
  set -euo pipefail
  
  # Clone the apps-deployment repository to a temporary directory
  rm -rf /tmp/apps-deployment
  git clone https://github.com/Piotr1215/apps-deployment /tmp/apps-deployment
  cd /tmp/apps-deployment
  
  # Create a new branch
  git checkout -b add-team2-claim
  
  # Create the claim file
  mkdir -p vcluster-team2-apps
  cp {{vcluster}}/team2-claim.yaml vcluster-team2-apps/
  
  # Add application to sync with vCluster
  cat > vcluster-team2-apps/application.yaml << 'EOL'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: team2-claim
  namespace: argocd
spec:
  destination:
    namespace: team2
    server: https://kubernetes.default.svc/api/v1/namespaces/team2/services/team2-vcluster:8443/proxy
  project: default
  source:
    path: vcluster-team2-apps
    repoURL: https://github.com/Piotr1215/apps-deployment
    targetRevision: HEAD
    directory:
      include: team2-claim.yaml
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
EOL

  # Add and commit changes
  git add vcluster-team2-apps/
  git commit -m "Add claim for Team2 vCluster"
  
  # Push and create PR
  git push -u origin add-team2-claim
  gh pr create --title "Add claim for Team2 vCluster" --body "This PR adds a claim that will be deployed to the Team2 vCluster."

# cleanup vCluster demo
cleanup_vcluster_demo:
  #!/usr/bin/env bash
  set -euo pipefail
  
  # Delete the ArgoCD applications
  kubectl delete application vcluster-team2 -n argocd || true
  kubectl delete application team2-claim -n argocd || true
  
  # Delete the team2 namespace and all resources in it
  kubectl delete namespace team2 --cascade=true || true

# * delete KIND cluster
teardown:
  #!/usr/bin/env bash
  set -euo pipefail

  cd {{kind}} && terraform destroy -auto-approve