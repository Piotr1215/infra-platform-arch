set export
set shell := ["bash", "-uc"]
                                 
yaml          := justfile_directory() + "/yaml"
secrets       := justfile_directory() + "/secrets"
apps          := justfile_directory() + "/apps"
kind          := justfile_directory() + "/tf-kind"
              
browse        := if os() == "linux" { "xdg-open "} else { "open" }
copy          := if os() == "linux" { "xsel -ib"} else { "pbcopy" }
replace       := if os() == "linux" { "sed -i"} else { "sed -i '' -e" }

export base64encoded_azure_creds    := `base64 ~/crossplane-azure-provider-key.json | tr -d "\n"`
              
argocd_port   := "30950"
                                 
# this list of available targets
# targets marked with * are main targets
default:
  just --list --unsorted

# * setup kind cluster with crossplane, ArgoCD and launch argocd in browser
setup: setup_kind setup_crossplane setup_argo create_azure_secret create_providers bootstrap_apps

create_azure_secret:
  @envsubst < {{secrets}}/azure-provider-secret.yaml | kubectl apply -f - 

create_providers:
  envsubst < {{yaml}}/azure-provider.yaml | kubectl apply -f - 
  envsubst < {{yaml}}/kubernetes-provider.yaml | kubectl apply -f - 
  envsubst < {{yaml}}/http-provider.yaml | kubectl apply -f -
  kubectl wait --for condition=healthy --timeout=300s provider.pkg --all
  envsubst < {{yaml}}/azure-provider-config.yaml | kubectl apply -f - 
  envsubst < {{yaml}}/http-provider-config.yaml | kubectl apply -f -
  envsubst < {{yaml}}/kubernetes-provider-config.yaml | kubectl apply -f -
  envsubst < {{yaml}}/functions.yaml | kubectl apply -f -
  envsubst < {{yaml}}/resource-group.yaml | kubectl apply -f -
  just apply_composition

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
  watch crossplane beta trace appclaim.acmeplatform.com/platform-demo

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
  helm upgrade --install crossplane --namespace {{xp_namespace}} crossplane-stable/crossplane --devel
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

# * delete KIND cluster
teardown:
  #!/usr/bin/env bash
  set -euo pipefail

  cd {{kind}} && terraform destroy -auto-approve
