#!/bin/bash
# Simple test script for the Team2 vCluster Demo

set -e

echo "===== Starting Simple Team2 vCluster Demo ====="

# 1. Create team2-demo namespace and vCluster
echo "1. Creating team2-demo namespace and vCluster..."
kubectl create namespace team2-demo 
vcluster create team2-demo-vcluster -n team2-demo --upgrade -f ./team2-vcluster-values.yaml

# 2. Connect to the vCluster with a separate kubeconfig
echo "2. Connecting to team2-demo vCluster..."
mkdir -p /tmp/team2-demo-vcluster
vcluster connect team2-demo-vcluster -n team2-demo --kube-config=/tmp/team2-demo-vcluster/kubeconfig.yaml --update-current=false

# 3. Install Crossplane in the vCluster
echo "3. Installing Crossplane in team2-demo vCluster..."
export KUBECONFIG=/tmp/team2-demo-vcluster/kubeconfig.yaml
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
helm upgrade --install crossplane \
    --namespace crossplane-system crossplane-stable/crossplane \
    --set args='{"--enable-usages"}' \
    --create-namespace

# 4. Wait for Crossplane to be ready
echo "4. Waiting for Crossplane to be ready..."
kubectl wait --for condition=Available=True --timeout=300s deployment/crossplane --namespace crossplane-system

# 5. Apply Azure providers
echo "5. Applying Azure providers..."
kubectl apply -f vcluster-setup/team2-providers.yaml
kubectl wait --for condition=healthy --timeout=300s provider.pkg --all || echo "Not all providers are healthy yet"

# Check if the Function CRD exists
if kubectl get crd functions.pkg.crossplane.io &>/dev/null; then
  echo "Function CRDs are available. Applying functions..."
  kubectl apply -f - <<EOF
---
apiVersion: pkg.crossplane.io/v1alpha1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.5.0
---
apiVersion: pkg.crossplane.io/v1alpha1
kind: Function
metadata:
  name: function-auto-ready
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-auto-ready:v0.2.1
EOF
  sleep 20
else
  echo "Function CRDs not available yet. Skipping function installation."
fi

# 7. Apply provider configurations
echo "7. Applying provider configurations..."
kubectl apply -f - <<EOF
---
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
---
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-creds
      key: credentials
EOF

# 8. Apply team2-specific composition and definition
echo "8. Applying team2 composition and definition..."
kubectl apply -f vcluster-setup/team2-composition.yaml
kubectl apply -f vcluster-setup/team2-definition.yaml

# 9. Apply team2 claim to create Azure resources
echo "9. Applying team2 claim..."
kubectl create namespace team2 --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f vcluster-setup/team2-claim.yaml -n team2

# 10. Check claim status
echo "10. Checking claim status..."
sleep 30
kubectl get infrastructureclaim,resourcegroup,account,container -n team2

echo "===== Team2 vCluster Demo Completed ====="
echo "To clean up the demo, run: just cleanup_team2_demo"
