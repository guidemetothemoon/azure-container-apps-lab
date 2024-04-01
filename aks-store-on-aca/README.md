# Implementation of AKS Store Demo App with Azure Container Apps

This folder contains Bicep code for provisioning [aks-store-demo](https://github.com/Azure-Samples/aks-store-demo), but on Azure Container Apps. Deployment also is created in a manner that's closer to an actual production scenario, including security hardening configuration.

Below you may find the solution architecture diagram:

TODO

Implementation includes following modules:

* ```common```: includes common, shared resources that are used by other resources in the deployment. For example, managed identities or deployment-specific Azure Policy assignments.
* ```network```: includes network-related resources. For example, virtual networks, subnets and network security groups.
* ```dns```: includes DNS-related resources. For example, private DNS zones.
* ```vnet_links```: includes virtual network link resources for mapping of virtual networks with private DNS zones, which is required for the private endpoints to function properly.
* ```kv```: includes Azure Key Vault resources, with enabled RBAC and configuration for secure access to the resources with private endpoints.
* ```azure_monitor```: includes observability-related resources, like Log Analytics, Application Insights, etc. It also includes Azure Monitor Private Link Scope (AMPLS) and related resources for configuration of secure access to Azure Monitor services.
* ```ai```: includes cognitive services, like Azure OpenAI with respective model deployments and configuration for secure access to the resources with private endpoints.
* ```aca_common```: includes resources that are common for Azure Container Apps, like Azure Container Apps environment and network configuration for secure communication to and between apps.
* ```internal_apps```: includes container apps that are not publicly accessible, i.e. internal services.
* ```public_apps```: includes container apps that are publicly accessible.
