Install-Module -Name AzureRM
Connect-AzureRMAccount
Get-AzureRMResourceGroup
Get-AzureRMVirtualnetworkGateway -ResourceGroupName tc-az-dr03
Get-AzureRMLocalNetworkGateway -ResourceGroupName tc-az-dr03


$LocalGateway = Get-AzureRmLocalNetworkGateway -Name "TriconElite-HQ" -ResourceGroupName "tc-az-dr03"
$LocalGateway
$VirtualGateway = Get-AzureRmVirtualNetworkGateway -Name "tc-az-dr03-vnet1-GW" -ResourceGroupName "tc-az-dr03"
$VirtualGateway

Set-AzureRmVirtualNetworkGatewayDefaultSite -GatewayDefaultSite $LocalGateway -VirtualNetworkGateway $VirtualGateway