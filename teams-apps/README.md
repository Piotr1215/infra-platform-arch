# Team Applications with Crossplane Claims

This directory contains Crossplane claims that will be deployed to team vClusters.

## Demo Steps

1. First, ensure the team infrastructure is set up by applying:
   ```bash
   kubectl apply -f teams-infra-app.yaml
   ```

2. Once the vCluster and Crossplane are set up, deploy the applications:
   ```bash
   kubectl apply -f teams-apps-app.yaml
   ```

3. Verify the claim was successfully applied:
   ```bash
   # Connect to the vCluster
   vcluster connect team2-vcluster -n team2
   
   # Check the claim
   kubectl get infrastructureclaim -n team2
   
   # Check Crossplane resources
   kubectl get composite -A
   ```