# ServianTechChallenge
Tech Challenge for Servian

Pre requisites for deployment:

- A Resouce group with a storage account needs to be configured to hold the
  Terraform state file.

- A Service Principal needs to be created and assigned to the storage account.

- From the Service principal the following need to be added to GitHub Secrets for
  use within GitHub Actions: 
    AZURE_AD_CLIENT_ID = Service Principal AppId
    AZURE_AD_CLEINT_SECRET = Service Principal Secret
    AZURE_SUBSCRIPTION_ID = Azure SubscriptionId
    ARM_TENANT_ID = Azure Tenant ID


Solution Architecture:

The solution for this challenge is to use Terraform to deploy the required infrastructure and application into Azure.

As the application is already avaliable in a container it is being deployed
into Azure Container Instances (ACI)

The database is set up using the Azure Postgres service with a private endpoint.

To secure the application and database from the public internet a Load Balancer
is used to direct only traffic on a specific port to the application container via the
public IP.
