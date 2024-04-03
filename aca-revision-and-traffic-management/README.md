# Revision and traffic management in Azure Container Apps

This folder contains Bicep code for provisioning a demo application that can be used to see multiple revisions and traffic splitting for Azure Container Apps in action. Demo application itself is a simple Hello World application that was initially created by Microsoft for AKS demos, but why not re-use it for Azure Container Apps as well? 😼

Implementation includes following modules:

* [common](modules/common.bicep): includes common, shared resources that are used by other resources in the deployment. For example, managed identities or deployment-specific Azure Policy assignments.
* [azure_monitor](modules/azure-monitor.bicep): includes observability-related resources, like Log Analytics, Application Insights, etc.
* [aca_common](modules/aca-common.bicep): includes resources that are common for Azure Container Apps, like Azure Container Apps environment.
* [public_apps](modules/aca-public-apps.bicep): includes container apps that are publicly accessible.

## Deployment instructions

1. Deploy code as-is first (after adjusting parameters as per your use case) - initially in [aca-public-apps.bicep](modules/aca-public-apps.bicep) it's defined that application will be deployed in multi-revision mode, but when we start from nothing only one, first, revision will be deployed. Due to that in ```*.bicepparam``` file traffic distribution is configured to send 100% traffic to the latest revision, which will be the app's very first revision.

2. Let's make a change to the application to create a new revision - in [aca-public-apps.bicep](modules/aca-public-apps.bicep) update ```TITLE``` environment variable with a new value that can identify new app revision. Next, let's update traffic distribution:
    2.1. Get name of the currently active, first app revision by running following Azure CLI command (update ```resource-group``` parameter with the one defined in the respective ```.bicepparam``` file): ```az containerapp revision list --name aca-hello-world --resource-group <acaResourceGroupName_parameter_value> --query [0].name -o tsv```
    2.2. In the respective ```.bicepparam``` file update ```trafficDistribution``` array: update weight number for ```latestRevision``` object - this object represents every new revision that's being provisioned. Uncomment second object and update ```revisionName``` value with the one retrieved in step 2.1. Then update ```weight``` value with the amount of traffic you want to send to the previous/initial revision. **Please note that weight for all revisions combined must be 100.**
3. Re-provision resources with the new changes. Go to the public URL of the app and do a bunch of refreshes to verify that traffic is now routed to both versions/revisions of the application.

### GitHub Actions Workflow

Example of a GitHub Actions Workflow has been set up for you to use in your own repository to provision resources in this folder. Workflow is available in [deploy-aca-revision-and-traffic-management.yaml](../.github/workflows/deploy-aca-revision-and-traffic-management.yaml) file in the root of the repository. Please note that you need to configure GitHub secrets for the workflow to be able to log into your Azure subscription and provision resources to it. I would recommend setting up a managed identity with federated credential for this purpose and give it Contributor permissions on the subscription level (resource group provisioning is part of the Bicep code, but you can also provision resource group outside of this deployment and then only give the identity permissions on the respective resource group's level).

Please refer following Microsoft documentation on how to set up managed identity with federated credentials for usage in GitHub Actions worfklow: [Use GitHub Actions to connect to Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux)
