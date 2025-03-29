# Demo Resources

This directory contains resources for the vCluster multitenancy demo. The files here are not directly used by ArgoCD, but are templates that will be copied to the repository root during the demo.

## Demo Flow

### Demo 1: Setting up Team2 Infrastructure

1. Run `just setup_teams_pr` to:
   - Copy `teams-infra-app.yaml` to the repository root
   - Create a PR with teams/ directory
   - Apply the ArgoCD application that watches the teams/ directory

2. Merge the PR to demonstrate how ArgoCD picks up the changes and deploys the Team2 vCluster

3. After the demo, run `just cleanup_teams_pr` to:
   - Remove the ArgoCD application
   - Delete the branch

### Demo 2: Setting up Team2 Applications

1. Run `just setup_teams_apps_pr` to:
   - Copy `teams-apps-app.yaml` to the repository root
   - Create a PR with teams-apps/ directory
   - Apply the ArgoCD application that watches the teams-apps/ directory

2. Merge the PR to demonstrate how ArgoCD picks up the claims and deploys them to the Team2 vCluster

3. After the demo, run `just cleanup_teams_apps_pr` to:
   - Remove the ArgoCD application
   - Delete the branch