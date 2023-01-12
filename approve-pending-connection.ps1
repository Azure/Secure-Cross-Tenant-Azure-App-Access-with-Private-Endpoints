#to be executed by the PROVIDER
#set the webAppId
$webAppId='THE PROVIDER WEBAPPID'

#get the private endpoint connection in pending state
az network private-endpoint-connection list --id $webAppId --query "[?properties.privateLinkServiceConnectionState.status=='Pending']"

#get the ID of the pending private endpoint connection - it will get the first pending request
$peId=az network private-endpoint-connection list --id $webAppId --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].{id:id}[0]" --output tsv

#approve the private endpoint connection
az network private-endpoint-connection approve --description "Approved" --id $peId