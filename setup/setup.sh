#!/bin/bash

error()
{
   [ -n "$@" ] && echo "ERROR: $@"
   [ -f _variables.json ] && rm _variables.json
   exit 1
}

# Default values

location=uksouth
resource_group_name=sap_hana_demo_resources
image_name=sap_hana_bootstrap_server

subscription_id=$(az account show --query id --output tsv) || error "Not logged in."
resource_group_id=/subscriptions/$subscription_id/resourceGroups/$resource_group_name
hash=$(base64 <<< $resource_group_id | tr -cd a-z0-9 | head -c 16)

# Check the providers are configured correctly

az feature show --name AllowNfsFileShares --namespace Microsoft.Storage --subscription $subscription_id --query properties.state --output tsv | grep -q "^Registered" || error "Register the NFS protocol and rerun. (https://docs.microsoft.com/azure/storage/files/storage-files-how-to-create-nfs-shares?tabs=azure-portal#register-the-nfs-41-protocol)"

# Read in the rhsm file if found

if [ -s variables.rhsm.json ]
then
  rhsm=$(cat variables.rhsm.json)
  rhsm_username=$(jq -r .rhsm_username//empty <<<$rhsm)
  rhsm_password=$(jq -r .rhsm_password//empty <<<$rhsm)
   rhsm_pool_id=$(jq -r .rhsm_pool_id//empty  <<<$rhsm)
fi

# If any of the RHSM variables are unset then request and write out again

if [ -z "$rhsm_username" -o -z "$rhsm_password" -o -z "$rhsm_pool_id" ]
then
  test -z "$rhsm_username" && read -ep  "RHSM username : " rhsm_username
  test -z "$rhsm_password" && read -esp "RHSM password : " rhsm_password
  test -z "$rhsm_pool_id"  && read -ep  "RHSM pool ID  : " rhsm_pool_id

  jq --arg u  $rhsm_username \
     --arg p  $rhsm_password \
     --arg id $rhsm_pool_id  \
     --null-input \
     '{rhsm_username:$u, rhsm_password:$p, rhsm_pool_id:$id}' \
    > variables.rhsm.json && chmod 600 variables.rhsm.json
else
  echo "Using variables in variables.rhsm.json"
fi

# Create the service principal and packer variable file if they don't exist

if [ ! -s variables.sp.json ]
then
  sp=$(az ad sp create-for-rbac --name http://hana --output json \
    | jq --arg sub_id $subscription_id \
      '.|{tenant_id:.tenant, subscription_id:$sub_id, client_id:.appId, client_secret:.password}')
else
  sp=$(cat variables.sp.json)
  echo "Using service principal variables in variables.sp.json"
fi

      tenant_id=$(jq -er .tenant_id//empty       <<<$sp) || error "Bad variables.sp.json"
subscription_id=$(jq -er .subscription_id//empty <<<$sp) || error "Bad variables.sp.json"
      client_id=$(jq -er .client_id//empty       <<<$sp) || error "Bad variables.sp.json"
  client_secret=$(jq -er .client_secret//empty   <<<$sp) || error "Bad variables.sp.json"

jq . <<< $sp > variables.sp.json && chmod 600 variables.sp.json


# Pre-determine the storage account name

if [ -s variables.azure.json ]
then
  storage_account_name=$(jq -er '.storage_account_name//empty' variables.azure.json) || error "Bad variables.azure.json"
        key_vault_name=$(jq -er '.key_vault_name//empty'       variables.azure.json) || error "Bad variables.azure.json"
  echo "Using storage account and key vault names from variables.azure.json."
else
  storage_account_name=nfs$hash
  key_vault_name=akv$hash
  jq --arg sa $storage_account_name --arg kv $key_vault_name --null-input \
    '{storage_account_name:$sa, key_vault_name:$kv}' > variables.azure.json
fi

# Defaults

set -x
export AZURE_DEFAULTS_GROUP=$resource_group_name
export AZURE_DEFAULTS_LOCATION=$location

# Create the resource group

az group create --name $resource_group_name --output yamlc

# Create a storage account

az storage account create --name $storage_account_name --sku Premium_LRS --kind FileStorage --output yamlc

# Create the premium file share and close off public access

az storage share-rm create --storage-account $storage_account_name --name saphana --enabled-protocol NFS --root-squash RootSquash --output yamlc
az storage account update --name $storage_account_name --bypass "AzureServices" --default-action "Deny" --output none

# Create the key vault and add secrets

az keyvault create --name $key_vault_name

az keyvault secret set --vault-name $key_vault_name --name "tenant-id"       --value $tenant_id        --output yamlc
az keyvault secret set --vault-name $key_vault_name --name "subscription-id" --value $subscription_id  --output yamlc
az keyvault secret set --vault-name $key_vault_name --name "client-id"       --value $client_id        --output yamlc
az keyvault secret set --vault-name $key_vault_name --name "client-secret"   --value $client_secret    --output yamlc

az keyvault secret set --vault-name $key_vault_name --name "rhsm-username"   --value $rhsm_username    --output yamlc
az keyvault secret set --vault-name $key_vault_name --name "rhsm-password"   --value $rhsm_password    --output yamlc
az keyvault secret set --vault-name $key_vault_name --name "rhsm-pool-id"    --value $rhsm_pool_id     --output yamlc

# Merge the variables into a temporary file and create the image using Packer

if az image show --name $image_name --output none 2>/dev/null
then
  echo "Using existing image $image_name. (Delete and rerun to recreate.)"
else
  cat variables.rhsm.json variables.sp.json variables.azure.json | jq -s add > _variables.json && chmod 600 _variables.json
  packer build -var-file=./_variables.json sap_hana_bootstrap_server.json || error "Failed image build"
  rm _variables.json
fi

# Create managed identity and add an access policy

az identity create --name sap_hana_demo --output yamlc
object_id=$(az identity show --name sap_hana_demo --query principalId --output tsv)
az keyvault set-policy --object-id $object_id --name $key_vault_name --secret-permissions list get --output yamlc

# Add a tag to the resource group to include the resource names

az group update --name $resource_group_name --set tags.storage_account=$storage_account_name tags.key_vault=$key_vault_name --output yamlc

# Exit cleanly

unset AZURE_DEFAULTS_GROUP AZURE_DEFAULTS_LOCATION
exit 0
