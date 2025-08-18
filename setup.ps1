$group = "rg-aks-localdns"
$cluster = "localdnscluster"

# create the group
az group create -n $group -l eastus2

# create a basic cluster
az aks create -n $cluster -g $group -c 1

# enable localdns on the system nodepool
az aks nodepool update `
    -g $group `
    --cluster-name $cluster `
    -n nodepool1 `
    --localdns-config .\dnsconfig.json

# add a nodepool with localdns enabled
az aks nodepool add `
    -g $group `
    --cluster-name $cluster `
    --mode User `
    -n appspool `
    --localdns-config .\dnsconfig.json

# get credentials
az aks get-credentials -n $cluster -g $group --overwrite-existing
