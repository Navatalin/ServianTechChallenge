# Tech Challenge for Servian

## Pre requisites for deployment:

- A Resouce group with a storage account needs to be configured to hold the Terraform state file.

- A Service Principal needs to be created and assigned to the storage account.

- From the Service principal the following need to be added to GitHub Secrets for use within GitHub Actions: 
    - AZURE_AD_CLIENT_ID = Service Principal AppId
    - AZURE_AD_CLEINT_SECRET = Service Principal Secret
    - AZURE_SUBSCRIPTION_ID = Azure SubscriptionId
    - ARM_TENANT_ID = Azure Tenant ID

- main.tf backend section needs to be updated to reflect storage account details and define the name for the storage container and the state file.

- For the database password a GitHub Secret with the name DB_PASSWORD needs to be configured. This secret is used to set the Postgres DB password.
## Solution Architecture:

The solution for this challenge is to use Terraform to deploy the required infrastructure and application into Azure.

As the application is already avaliable in a container Azure Container Instances (ACI) was chosen to run the appplication.

The initial plan was to use Azure Postgres service, however due to an issue with the username expecting the format usernamer@host it was decided to switch to a container version of postgres and include it inside of the application ACI.

Both containers are being run in the same ACI which allows for a local connection between the application and database.

To secure the application and database from the public internet a Load Balancer is used to direct only traffic on a specific port to the application container via the public IP.

Automation is configured using GitHub actions. There are two workflows: terraform-plan.yml and terraform-apply.yml
The plan version is used on all pushes to the main branch to validate and test the configuration.

The apply version is set to workflow_dispatch so it requires a manual approval to run, this is done to have more control on when the configuration is applied to the environment.