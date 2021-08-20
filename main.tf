terraform {
  backend "azurerm" {
      resource_group_name = "terraform-states"
      storage_account_name = "dmccterraformstroage"
      container_name = "tfstates"
      key = "tfstates.tfstate"
  }
}

provider "azurerm" {
  features {    
  }
}

data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "spa-site" {
    name = "spa-site"
    location = "southeastasia"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
    name = "spa-site-vnet"
    address_space = ["10.0.0.0/16"]
    location = azurerm_resource_group.spa-site.location
    resource_group_name = azurerm_resource_group.spa-site.name
}

# Dedicated subnet for use with Azure Container Instances
resource "azurerm_subnet" "container_subnet" {
  name = "container_subnet"
  resource_group_name = azurerm_resource_group.spa-site.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes = ["10.0.1.0/24"]
  service_endpoints = ["Microsoft.Sql"]

    delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Public IP
resource "azurerm_public_ip" "spa-public-ip" {
  name = "spa-public-ip"
  resource_group_name = azurerm_resource_group.spa-site.name
  location = azurerm_resource_group.spa-site.location
  allocation_method = "Static"
  sku = "Standard"
}

# Network Profile for Azure Container Instances
resource "azurerm_network_profile" "spa-aci-profile" {
  name = "spa-aci-profile"
  location = azurerm_resource_group.spa-site.location
  resource_group_name = azurerm_resource_group.spa-site.name

  container_network_interface {
    name = "spa-aci-nic"

    ip_configuration {
      name = "spa-aci-ipconfig"
      subnet_id = azurerm_subnet.container_subnet.id
    }
  }
}

# Azure Container Instances and Container definition
resource "azurerm_container_group" "spa-aci" {
  name = "spa-aci"
  location = azurerm_resource_group.spa-site.location
  resource_group_name = azurerm_resource_group.spa-site.name
  ip_address_type = "private"
  network_profile_id = azurerm_network_profile.spa-aci-profile.id
  os_type = "Linux"

  container {
    name = "postgres"
    image = "postgres:9.6"
    cpu = "0.5"
    memory = "1.0"

    ports {
      port = 5432
      protocol = "TCP"
    }

    environment_variables = {
      "POSTGRES_PASSWORD" = "$StoreSecurely!99"
      "POSTGRES_USER" = "pgadmin"
      "POSTGRES_DB" = "testdb"
    }
  }

  container {
    name = "spa"
    image = "servian/techchallengeapp:latest"
    cpu = "0.5"
    memory = "1.0"

    ports {
      port = 3000
      protocol = "TCP"
    }

    environment_variables = {
        "VTT_DBUSER" = "pgadmin@${ azurerm_postgresql_server.spa-db-server.fqdn }}"
        # Temp value, store securely in Github Secrets
        "VTT_DBPASSWORD" = "$StoreSecurely!99"
        "VTT_DBNAME" = "testdb"
        "VTT_DBPORT" = "5432"
        "VTT_DBHOST" = azurerm_postgresql_server.spa-db-server.fqdn
        "VTT_LISTENHOST" = "0.0.0.0"
        "VTT_LISTENPORT" = "3000"
    }

    commands = ["sh","-c","./TechChallengeApp updatedb && ./TechChallengeApp serve"]
  }
}

# Load Balancer connected to public IP
resource "azurerm_lb" "spa-lb" {
  name = "spa-lb"
  location = azurerm_resource_group.spa-site.location
  resource_group_name = azurerm_resource_group.spa-site.name
  sku = "Standard"

  frontend_ip_configuration {
    name = "publicIP"
    public_ip_address_id = azurerm_public_ip.spa-public-ip.id
  }
}

# Backend address pool for Load Balancer
resource "azurerm_lb_backend_address_pool" "spa-lb-backend" {
  loadbalancer_id = azurerm_lb.spa-lb.id
  name = "spa-lb-backend"
}

# Network Address to add to backend pool
resource "azurerm_lb_backend_address_pool_address" "spa-lb-backend-address" {
  name = "spa-lb-backend-address"
  backend_address_pool_id = azurerm_lb_backend_address_pool.spa-lb-backend.id
  virtual_network_id = azurerm_virtual_network.vnet.id
  ip_address = azurerm_container_group.spa-aci.ip_address
}

# Health Probe for Load Balancer
resource "azurerm_lb_probe" "spa-lb-probe" {
  name = "spa-lb-probe"
  resource_group_name = azurerm_resource_group.spa-site.name
  loadbalancer_id = azurerm_lb.spa-lb.id
  protocol = "HTTP"
  request_path = "/"
  port = 3000
  interval_in_seconds = 5
  number_of_probes = 2
}

# Load balancer rule to open up port for application
resource "azurerm_lb_rule" "spa-lb-rule" {
  name = "spa-lb-rule"
  resource_group_name = azurerm_resource_group.spa-site.name
  loadbalancer_id = azurerm_lb.spa-lb.id
  protocol = "Tcp"
  frontend_port = "3000"
  backend_port = "3000"
  frontend_ip_configuration_name = "publicIP"
  backend_address_pool_id = azurerm_lb_backend_address_pool.spa-lb-backend.id
  probe_id = azurerm_lb_probe.spa-lb-probe.id
}