$login = az login --output json | ConvertFrom-Json
$SubscriptionId = $login.id;
az account set --subscription $SubscriptionId;
$subscription = "/subscriptions/$SubscriptionId"
$principal = az ad sp create-for-rbac --role="Contributor" --scopes=$subscription | ConvertFrom-Json

$env:ARM_CLIENT_ID = $principal.appId
$env:ARM_CLIENT_SECRET = $principal.password
$env:ARM_SUBSCRIPTION_ID = $SubscriptionId
$env:ARM_TENANT_ID = $principal.tenant
$env:TF_VAR_resource_group_name = "codetalks-rg"
$env:TF_VAR_cluster_name = "codetalks-aks"

# helm provider => aks kube_config or certificates or exec cmd to fetch from aks

# kubernetes provider =>  aks kube_config or certificates or exec cmd to fetch from aks



