# Team2 Applications

This directory contains Crossplane claims that will be deployed to the Team2 vCluster.

During the demo, you can create a PR to add a claim file here and ArgoCD will automatically deploy it to the Team2 vCluster.

Example claim file (team2-claim.yaml):
```yaml
apiVersion: acmeplatform.com/v1alpha1
kind: InfrastructureClaim
metadata:
  labels:
    team: team2
  name: team2-demo
  namespace: team2
spec:
  compositionRef:
    name: team2-azure-infra
  parameters:
    containerName: team2-blob-container
    storageSuffix: "abc456xyz"
```