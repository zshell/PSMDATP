function Get-MDATPAlert{
    <#
    .Synopsis
    Get-MDATPAlert

    .Description
    Get-MDATPAlert retrieves Microsoft Defender Advanced Threat Protection alerts exposed  through the Microsoft Defender Advanced Threat Protection Alerts Rest API.

    .PARAMETER Severity
    Provides an option to filter the output by Severity. Low, Medium, High.

    .PARAMETER PastHours
    Provides an option to filter the results by past hours when the alert was created.

    .PARAMETER MTPConfigFile
    The MTPConfigFile contains the API connection information, if not specified a default PoshMTPconfig.json  is used that must be located in the module folder

    .EXAMPLE
    Get-WDATPAlert

    This command retrieves all alerts

    .EXAMPLE
    Get-MDATPAlert -PastHours 168 -Severity Informational

    This command retrieves all alerts from the past 7 days with severity level Informational

    .NOTES
    Version:        1.2
    Author:         Alex Verboon
    Creation Date:  18.07.2020
    Purpose/Change: updated API uri

    #>
    [CmdletBinding()]
    Param(
        # Alert Severity level
        [Parameter(Mandatory=$false)]
        [ValidateSet('High', 'Medium', 'Low','Informational')]
        [String]$Severity,

        # Show alerts from past n hours
        [Parameter(Mandatory=$false)]
        [ValidateSet('12', '24', '48','72','168','720')]
        [String]$PastHours,

        # API Configuration file
        [Parameter(Mandatory=$false)]
        [String]$MTPConfigFile
    )

    Begin{
        # Begin Get API Information

        If ($MTPConfigFile){
            $PoshMTPconfigFilePath = $MTPConfigFile
            Write-Verbose "MTP ConfigFile parameter: $PoshMTPconfigFilePath"
        }
        Else{
            # If no configfile is defined we use a defined lcoation .\PoshMTPconfig.json
            $ConfigFileDir =  [IO.Directory]::GetParent($PSScriptRoot)
            $PoshMTPconfigFilePath = "$ConfigFileDir\" +  "PoshMTPconfig.json"
            Write-Verbose "MTP ConfigFile static: $PoshMTPconfigFilePath"
        }

        Write-Verbose "Checking for $PoshMTPconfigFilePath"
        If (Test-Path -Path $PoshMTPconfigFilePath -PathType Leaf){
            $ConfigSettings = @(Get-Content -Path "$PoshMTPconfigFilePath" | ConvertFrom-Json)
            $OAuthUri = $ConfigSettings.API_MDATP.OAuthUri
            $ClientID = $ConfigSettings.API_MDATP.ClientID
            $ClientSecret = $ConfigSettings.API_MDATP.ClientSecret
        }
        Else{
            Write-Error "$PoshMTPconfigFilePath not found"
            Break
        }

        # End Get API Information

        #WDATP Alerts - Europe
        $uri = "https://api.securitycenter.windows.com/api/alerts"
  
        # Connect with MDATP API
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Body = @{
            resource      = "https://api.securitycenter.windows.com"
            client_id     = "$ClientID"
            client_secret = "$ClientSecret"
            grant_type    = 'client_credentials'
            redirectUri   = "https://localhost:8000"
        }
        $Response = Invoke-RestMethod -Method Post -Uri $OAuthUri -Body $Body
        $Headers = @{ Authorization = "Bearer $($Response.access_token)"}

    }
    Process{
        # Define the time range
        If ($null -eq $PastHours){
            $PastHours = 24
        }
        Else{
            $dateTime = (Get-Date).ToUniversalTime().AddHours(-$PastHours).ToString("o")
            $body = @{sinceTimeUtc = $dateTime}
        }

        # Retrieve MDATP alert data
        Try{
            $output = @(Invoke-RestMethod -Uri $uri -Headers $Headers -Body $Body -Method Get -Verbose -ContentType application/json)
        }
        Catch{
            $errorMessage = $_.Exception.Message
            Write-Error "Error retrieving MDATP alert data [$errorMessage]"
        }

        # Handle the output
        If ([string]::IsNullOrEmpty($Severity)){
            $output.value
        }
        Else{
            $output.value | Where-Object {$_.Severity -eq "$Severity"}
        }
    }
    End{
    }
}