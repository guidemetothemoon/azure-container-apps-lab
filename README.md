# Azure Container Apps - Demos and useful resources

This repository contains the source code for different use cases of implementation of Azure Container Apps. Some of these use cases are used for demos in **"From zero to production with Azure Container Apps"** technical session presented by Kristina Devochko. Long-term plan is to include additional useful resources in this repo, like links to blog posts and other helpful content related to all things Azure Container Apps.

Repository is improved continuously and currently includes four use cases that can be found in the respective folders:

* (Work In Progress) ```aca-nginx``` folder contains Bicep code for implementing path-based routing between Azure Container Apps, where NGINX is running as a separate container app and acts as a proxy server, routing traffic according to the configured paths, to the other container apps.

* [aca-revision-and-traffic-management](aca-revision-and-traffic-management/) folder contains a simple Hello World container app that has multiple revision mode configured, which can be used to see revisions and traffic (traffic splitting for blue-green deployment) management in action, once changes are made to the application.

* (Work In Progress) ```aca-with-windows-on-aci``` folder contains a use case where some applications require Windows containers and are running in Azure Container Instances while the rest of the applications are running as Linux containers in Azure Container Apps.

* [aks-store-on-aca](aks-store-on-aca/) folder contains implementation of [aks-store-demo](https://github.com/Azure-Samples/aks-store-demo) but on Azure Container Apps, with a configuration that's closer to a production scenario, including security hardening and proper configuration of dependent managed services.

All use cases are implemented with infrastructure-as-code with Bicep and are directly deployable. Deployment parameters can be adjusted as per your need and are located in Bicep parameter files in ```parameters``` folder in every use case's root folder.

If you would like to test out resource provisioning with CI/CD, and example of provisioning ```aca-revision-and-traffic-management``` scenario with GitHub Actions workflow, template code is available in [.github/workflows](.github/workflows/deploy-aca-revision-and-traffic-management.yaml) folder at the root of this repo.

## Additional reading material

Following links can be very useful to continue your journey in learning about Azure Container Apps:

* [Microsoft's documentation on Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps)
* [GitHub repository for Azure Container Apps issues and roadmap](https://github.com/microsoft/azure-container-apps​)
* [Azure Container Apps Roadmap](https://github.com/orgs/microsoft/projects/540)
* [How to analyze Azure Container Apps cost](https://github.com/microsoft/azure-container-apps/wiki/Analyze-your-ACA-Bill​)
* [Azure landing zone accelerator for Azure Container Apps](https://techcommunity.microsoft.com/t5/apps-on-azure-blog/announcing-landing-zone-accelerator-for-azure-container-apps​)
* [Path and hostname-based routing in Azure Container Apps with NGINX](https://techcommunity.microsoft.com/t5/apps-on-azure-blog/path-and-hostname-based-routing-in-azure-container-apps-with/ba-p/4068923)
