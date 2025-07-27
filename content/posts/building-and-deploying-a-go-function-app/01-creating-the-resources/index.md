+++
title = 'Creating the resources'
date = 2025-07-23T16:27:32+01:00
draft = true
tags = ['Golang', 'Azure', 'HCL', 'Bicep']
series = ['Building and Deploying a Go Function App']
series_order = 1
+++
I've done a couple of posts before on running [Go](https://go.dev) in [Azure Functions](https://learn.microsoft.com/azure/azure-functions/functions-custom-handlers) through the custom handler feature. This is an incredibly powerful feature which lets you write your handler code in any language you want, as long as it supports HTTP primitives.

The thing which always felt missing to me is that I've never pulled together different aspects of the process, from setting up the environment, building the code, deploying, and monitoring. So that's what I'm hoping to achieve with this series.

In this first part we're going to start by building out the target environment. We'll be doing this through Infrastructure-as-Code using [HCL](https://github.com/hashicorp/hcl) (the Hashicorp Scripting Language), though I'll be using [OpenTofu](https://opentofu.org) for running commands. Though there will be a [bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview) version as well, and I'll explain the differences between them where they exist.

So, lets dive in.

## What are we building?

We're going to build a simple application that will have the following features.

* Collect headlines from [NewsAPI](https://newsapi.org/) on a timed trigger
* Save the headlines to a SQL database, generating embeddings for each article
* Create APIs for
  * Listing headlines
  * Searching headlines
  * Generating a summary of headlines based on a user question

Whilst Azure Functions and SQL will form the large part of the solution, we're going to need supporting services for monitoring and security as well.

## Planning the resources

Let's start with the core services.

Azure Functions seems pretty straight forward, but we're going to need a little bit more. A Function App needs an [Azure App Service](https://learn.microsoft.com/azure/app-service/overview) to back it, so we'll need to deploy one of those. It also needs a storage account to persist data, and to use queues and tables if you use [Durable Functions](https://learn.microsoft.com/azure/azure-functions/durable/durable-functions-overview).

We also want to monitor the solution, so we are going to need to deploy an [App Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) instance. These require a [Log Analytics](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-overview) workspace to back them, so that's another resource needed.

We're going to need to store configuration information for the Function App, these can go into the environment settings which is nice and easy, but we shouldn't be storing secrets there (such as the NewsAPI key), best practice here is that we store these values in an [Azure KeyVault](https://learn.microsoft.com/azure/key-vault/general/overview) instance, and create links to it from the Function App.

Phew, that's quite a lot from the Function App, but don't worry, there's not a lot more.

Next up we have the [Azure SQL](https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview) database. This is easier as the only dependent service we'll need is an Azure SQL Server instance. We'll need to store the connection details in the KeyVault instance, but we've already got that covered.

Finally, we'll need an [Azure OpenAI](https://learn.microsoft.com/azure/ai-foundry/what-is-azure-ai-foundry) instance (Azure AI Foundry). We're going to deploy a Chat model and an Embeddings model to this as part of the deployment and we'll need to store the model deployment names in the Function App environment settings, and we'll need to store the API key in the KeyVault instance, and create a reference to it for the Function App.

![Azure Services](services.webp "The different services to be deployed")

## Getting started

Okay, lets first set up our basic files. We're going to need a `providers.tf` file, a `variables.tf` file, and a `main.tf` file. The first thing we'll do is configure our providers.

That file is going to look like this.

```terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.35.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~>3.4.5"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_secrets_on_destroy = true
      recover_soft_deleted_key_vaults       = true
    }
  }
  subscription_id              = var.subscription
  disable_terraform_partner_id = true
}
```

Here we're saying we require the `azurerm` provider and the `http` provider (you'll find out more about the http provider soon). The `azurerm` provider is what we'll use to create all of our Azure resources. The version at the time of writing is/was 4.35.0, but we prefix it with the `~>` modifier, that means that the "right-most" part of the version can change. So 4.35.1 or 4.35.2 can be downloaded instead, but not 4.36.0.

In our features section for `azurerm` we're configuring some defaults for KeyVault, such as saying that when an instance is destroyed it should also be purged (because KeyVault supports a soft delete), and that it should attempt to recover a soft-deleted version if one exists instead of trying to create a new one with the same name, which would give us an error.

We have to define the subscription we're deploying to, so we'll pull that from our variables in case we want to deploy to different subscriptions.

We'll also prevent it from adding the terraform partner id, because I just don't want it to add it.

So lets add the variable to our variables file (variables.tf) otherwise it'll complain.

```terraform
variable "subscription" {
  type        = string
  description = "The id of the subscription to deploy to"
  validation {
    condition     = length(var.subscription) > 0
    error_message = "A subscription id must be provided"
  }
}
```

This is a simple entry which defines the variable and says that it's length should be greater than 0 (so it's required).
