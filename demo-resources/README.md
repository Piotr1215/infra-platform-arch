# Demo Resources

This directory contains resources for the vCluster multitenancy demo. The files here are templates for ArgoCD applications that will be applied during the demo.

## Demo Flow

### Demo 1: Setting up Team2 Infrastructure with vCluster

1. Run `just setup_vcluster_pr` to:
   - Apply the vcluster-app.yaml ArgoCD application
   - Create a PR in the apps-deployment repository with vCluster setup files

2. Merge the PR to demonstrate how ArgoCD picks up the changes and deploys Team2 vCluster

### Demo 2: Setting up Team2 Applications

1. Run `just setup_team2_claim_pr` to:
   - Create a PR in the apps-deployment repository with claim files
   - Set up an ArgoCD application to deploy the claim to the Team2 vCluster

2. Merge the PR to demonstrate how ArgoCD picks up the claim and deploys it to the Team2 vCluster

### Cleanup

After the demo, run `just cleanup_vcluster_demo` to:
   - Remove the ArgoCD applications
   - Delete the team2 namespace and all resources in it