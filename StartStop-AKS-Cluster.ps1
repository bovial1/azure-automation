<#
.SYNOPSIS 
    This automation runbook is designed to manage the start and stop of aks clusters on a given schedule.

.DESCRIPTION
    This automation runbook is designed to manage the start and stop of aks clusterson a given schedule.
    The following modules to be imported in the modules section of the Automation Account in the Azure Portal:
    - Az.Account

.PARAMETERS
    aksClusterResourceId: This REQUIRED string parameter represents the cluster resource Id and contains all the necessary information for the action to be taken.

    operation: This REQUIRED string parameter represents the operations to be performed on the AKS cluster. It can only contain 2 values: Start or Stop
    

.EXAMPLE
    .\StartStop-AKS-Cluster

.NOTES
    AUTHOR:  Bo Vial 
    LASTEDIT: December 22nd, 2022
    CHANGELOG:
        VERSION:  1.0
        - Initial version
#>


Param(
    [Parameter(Mandatory=$True,
                ValueFromPipelineByPropertyName=$false,
                HelpMessage='Specify the AKS cluster resource Id.',
                Position=1)]
                [String]
                $aksClusterResourceId,
                
    [Parameter(Mandatory=$True,
                ValueFromPipelineByPropertyName=$false,
                HelpMessage='Specify the operation to be performed on the AKS cluster name (Start/Stop).',
                Position=2)]
                [ValidateSet('Start','Stop')]
                [String]
                $operation
    )

try
{
    "Logging in to Azure using the Managed Identity assigned to this automation account ..."
    Connect-AzAccount -Identity | Out-Null
    
    #Start/Stop cluster
    #az aks $operation --name $aksClusterName --resource-group $resourceGroupName
    #POST https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ContainerService/managedClusters/{resourceName}/stop?api-version=2021-05-01
        
    #Setting REST API Authentication token
    $accToken = Get-AzAccessToken | Select-Object -Property Token
    $AccessToken = $accToken.Token
    $headers_Auth = @{'Authorization'="Bearer $AccessToken"}

    #Setting GET RestAPI Uri
    $getRestUri = "https://management.azure.com/$($aksClusterResourceId)?api-version=2021-05-01"

    #Setting POST RestAPI Uri
    #$postRestUri = "https://management.azure.com/subscriptions/$($servicePrincipalConnection.SubscriptionId)/resourceGroups/$resourceGroupName/providers/Microsoft.ContainerService/managedClusters/$aksClusterName/$($operation.ToLower())?api-version=2021-05-01"
    $postRestUri = "https://management.azure.com/$aksClusterResourceId/$($operation.ToLower())?api-version=2021-05-01"

    try
    {
        #Retrieving cluster name from the resource Id
        $aksClusterName = $($aksClusterResourceId -split '/')[8]
        
        #Getting the cluster state
        Write-Output "Invoking RestAPI method to get the cluster state. The request Uri is ==$getRestUri==."
        $getResponse = Invoke-WebRequest -UseBasicParsing -Method Get -Headers $headers_Auth -Uri $getRestUri
        $getResponseJson = $getResponse.Content | ConvertFrom-Json
        $clusterState = $getResponseJson.properties.powerState.code
        Write-Output "AKS Cluster ==$aksClusterName== is currently ==$clusterState=="

        #Checking if the requested operation can be performed based on the current state
        Switch ($operation)
        {
            "Start"
            {
                If ($clusterState -eq "Running")
                {
                    Write-Output "The AKS Cluster ==$aksClusterName== is already ==$clusterState== and cannot be started again."
                }
                else
                {
                    Write-Output "Invoking RestAPI method to perform the requested ==$operation== operation on AKS Cluster ==$aksClusterName==. The request Uri is ==$postRestUri==."
                }
            }
            
            "Stop"
            {
                If ($clusterState -eq "Stopped")
                {
                    Write-Output "The AKS Cluster ==$aksClusterName== is already ==$clusterState== and cannot be stopped again."
                }
                else
                {
                    Write-Output "Invoking RestAPI method to perform the requested ==$operation== operation on AKS Cluster ==$aksClusterName==. The request Uri is ==$postRestUri==."
                }
            }

            Default
            {
                Write-Output "Unexpected scenario. The requested operation ==$operation== was not matching any of the managed cases."
            }
        }

        #Performning the operation
        $postResponse = Invoke-WebRequest -UseBasicParsing -Method Post -Headers $headers_Auth -Uri $postRestUri
        $StatusCode = $postResponse.StatusCode
    }
    catch
    {
        $StatusCode = $_.Exception.Response.StatusCode.value__
        $exMsg = $_.Exception.Message
        Write-Output "Response Code == $StatusCode"
        Write-Output "Exception Message == $exMsg"
    }

    if (($StatusCode -ge 200) -and ($StatusCode -lt 300))
    {
        Write-Output "The ==$operation== operation on AKS Cluster ==$aksClusterName== has been completed succesfully."
    }
    else
    {
        Write-Output "The ==$operation== operation on AKS Cluster ==$aksClusterName== was not completed succesfully."
    }

}
catch
{
    Write-Error -Message $_.Exception
    throw $_.Exception
}
