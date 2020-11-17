# cloud-azure-aks-addon (Run in Cloud Shell - Powershell)

Clone the Azure CLI code, upload it to your cloud shell and run! :)

## Add Aks-addon for all your AKS clusters
Azure Policy brings a new ability to apply at-scale enforcements and safeguards on your clusters in a centralized, consistent manner. Azure Policy makes it possible to manage and report on the compliance state of your Kubernetes clusters from one place. 
For full document: https://docs.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#overview

Script is running over all your subscriptions in the tenant and, if exist an AKS cluster the deployment will begin for all the clusters in subscription. 

# Additional Resources
AKS Addon - https://docs.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks

# Updates log
## 17TH NOVEMBER

* Replaced Service Principal credentials in managed Identity provides for a cleaner solution
*	Changed random generation to Random Pet
*	Added AAD group for Cluster admins
*	Added data source connection based on automatically updated version
*	Adding also OMS agent for Security Center detection and deny potentially insecure configurations.
