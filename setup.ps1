$group = "rg-aks-localdns"
$cluster = "localdnscluster"
$location = "northcentralus"
$nodeVmSize = "Standard_D4s_v5"
$localDnsConfig = ".\dnsconfig.json"

# create the group
az group create -n $group -l $location

# create a cluster with a supported linux image and at least 4 vcpus per node
az aks create -n $cluster -g $group -l $location -c 2 -s $nodeVmSize --os-sku Ubuntu2204

# enable localdns on the system nodepool; this reimages the pool
az aks nodepool update `
    -g $group `
    --cluster-name $cluster `
    -n nodepool1 `
    --localdns-config $localDnsConfig

# add a nodepool with localdns enabled
az aks nodepool add `
    -g $group `
    --cluster-name $cluster `
    --mode User `
    -n appspool `
    -s $nodeVmSize `
    --os-sku Ubuntu2204 `
    --localdns-config $localDnsConfig

# get credentials
az aks get-credentials -n $cluster -g $group --overwrite-existing
