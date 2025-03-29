# Team Infrastructure with vCluster

This directory contains configurations for setting up team infrastructure using vCluster and Crossplane.

## Demo Steps

1. Set up the teams infrastructure by applying the ArgoCD application:
   ```bash
   kubectl apply -f teams-infra-app.yaml
   ```

2. Once the vCluster and Crossplane are set up, set up the teams applications by applying the second ArgoCD application:
   ```bash
   kubectl apply -f teams-apps-app.yaml
   ```

3. Verify the setup:
   ```bash
   # Connect to the vCluster
   vcluster connect team2-vcluster -n team2
   
   # Verify Crossplane is running
   kubectl get pods -n crossplane-system
   
   # Verify the claim is created
   kubectl get infrastructureclaim -n team2
   ```