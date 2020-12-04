# README

## Background

References

* <https://www.redhat.com/en/blog/automate-your-sap-hana-system-replication-deployment-using-ansible-and-rhel-system-roles-sap>
* <https://github.com/hashicorp/packer/blob/88e03280b695e5db097bbccb6dba3d4e92274b13/builder/azure/examples/rhel.json>

This set of Packer, Ansible and Terraform is used to create SAP Hana demo environments. The bootstrap server is created from an image for faster deployment speed.

## Prereqs

You will need to install Packer, Terraform and Ansible for Azure, as well as the Azure CLI and jq. This repo is based on using Ubuntu in WSL2.

**Create a list with links.**

## Service Principal

OK, we'll create a service principal for this. Note that it will get the default Contributor access on your current subscription. We'll also create the variables file for the Packer job.

```bash
az ad sp create-for-rbac --name http://hana --output json | jq --arg sub_id $(az account show --query id --output tsv) '.|{tenant_id:.tenant, subscription_id:$sub_id, client_id:.appId, client_secret:.password}' > hana_service_principal.json
```

**OK, I actually created an HCL2 version...**
