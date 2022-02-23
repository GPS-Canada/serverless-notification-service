Param(  
   [string][Parameter(Mandatory)]$AppNamePrefix # Prefix used for creating applications
)

$resourceGroup = $AppNamePrefix
$functionAppName = "$AppNamePrefix-func" 

$configuration = "release"
$projectName = "serverless-notification-service"
$publishPath = "..\Publish\$configuration"
$publishFile = "..\Publish\$configuration.zip"


dotnet publish ..\$projectName.csproj `
    --configuration $configuration `
    --output $publishPath

Compress-Archive -Path "$publishPath\*" -DestinationPath $publishFile -Force

az functionapp deployment source config-zip `
    --resource-group $resourceGroup `
    --name $functionAppName `
    --src $publishFile
