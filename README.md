# Infrastructure Platform Architecture Demo

This repository demonstrates a platform architecture using Crossplane, KIND clusters, and vCluster for multi-tenancy. This README will guide you through setting up the environment and running the demos.

## Prerequisites

Before starting, ensure you have the following tools installed on your machine:

### Just Command Runner

[Just](https://github.com/casey/just) is a handy command runner used to simplify complex operations.

```bash
# On macOS
brew install just

# On Linux
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash

# On Windows using scoop
scoop install just
```

### KIND (Kubernetes IN Docker)

[KIND](https://kind.sigs.k8s.io/) is used to run Kubernetes clusters locally using Docker containers as nodes.

```bash
# On macOS
brew install kind

# On Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# On Windows
choco install kind
```

### Terraform

[Terraform](https://www.terraform.io/downloads) is used to provision the KIND cluster.

```bash
# On macOS
brew install terraform

# On Linux
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform

# On Windows
choco install terraform
```

### vCluster CLI

[vCluster](https://www.vcluster.com/docs/getting-started/setup) is used to create virtual Kubernetes clusters.

```bash
# On macOS
brew install loft-sh/tap/vcluster

# On Linux
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64" && sudo install -c -m 0755 vcluster /usr/local/bin && rm -f vcluster

# On Windows
# Download from https://github.com/loft-sh/vcluster/releases
# Add the directory to your PATH
```

### Kubernetes CLI (kubectl)

```bash
# On macOS
brew install kubectl

# On Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# On Windows
choco install kubernetes-cli
```

### Azure Provider Setup (required for Azure resources)

To configure Crossplane for Azure, you'll need:

1. An Azure account
2. Azure CLI installed
3. Service Principal credentials

```bash
# Login to Azure
az login

# Create Service Principal
az ad sp create-for-rbac --sdk-auth --role Owner > crossplane-azure-provider-key.json

# Encode the credentials for later use
base64 ~/crossplane-azure-provider-key.json | tr -d "\n" > ~/base64encoded_azure_creds.txt
```

## Getting Started

### Step 1: Clean up any existing Terraform state

If you're restarting after a previous run or troubleshooting, first clean up the Terraform state:

```bash
just cleanup_terraform
```

### Step 2: Set up the Kubernetes environment

This step creates the KIND cluster, installs Crossplane, and sets up all required infrastructure:

```bash
just setup
```

This will:
1. Create a KIND cluster named "demo-local"
2. Install Crossplane
3. Configure all necessary providers
4. Set up compositions and definitions
5. Install monitoring tools

The setup may take a few minutes to complete.

### Step 3: Deploy a sample claim

Once the environment is set up, you can deploy a sample claim to test the infrastructure:

```bash
kubectl apply -f sample-claim.yaml
```

To watch the claim being processed:

```bash
just watch_claim
```

### Step 4: Set up a vCluster

To demonstrate multi-tenancy with vCluster:

```bash
just vcluster_setup
```

This creates a virtual Kubernetes cluster within your main cluster, complete with its own Crossplane installation.

### Step 5: Create a vCluster claim

To deploy a sample claim in the vCluster:

```bash
just vcluster_create_claim
```

The claim will provision resources based on the compositions defined in the vCluster.

### Cleaning Up

To clean up the vCluster and its resources:

```bash
just vcluster_cleanup_claim
```

To completely tear down the environment:

```bash
just teardown
```

## Repository Structure

- `tf-kind/`: Terraform configuration for setting up the KIND cluster
- `yaml/`: Crossplane compositions, definitions, and provider configurations
- `vcluster-setup/`: Configuration files for vCluster setup
- `apps/`: Application resources for ArgoCD

## Troubleshooting

### KIND Cluster Issues

If you encounter issues with the KIND cluster:

```bash
# Check if the KIND cluster exists
kind get clusters

# If it exists but Terraform can't find it
just cleanup_terraform
just setup
```

### Crossplane Provider Issues

If providers aren't becoming healthy:

```bash
# Check provider status
kubectl get providers -A

# Check for errors in provider pods
kubectl get pods -n crossplane-system
kubectl logs -n crossplane-system <provider-pod-name>
```

### vCluster Connection Issues

If you can't connect to vCluster:

```bash
# List vClusters
vcluster list

# Try connecting again
vcluster connect team2-vcluster -n team2
```

## Additional Resources

- [Crossplane Documentation](https://docs.crossplane.io/latest/)
- [vCluster Documentation](https://www.vcluster.com/docs/)
- [KIND Documentation](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Terraform Documentation](https://www.terraform.io/docs)