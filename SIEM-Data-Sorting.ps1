# Define the base path for storing processed audit data 
$CompanyName = "YourCompany"  # Replace with the company name
$AuditBasePath = "C:\SOC2_Audit\$CompanyName"
$TodayDate = (Get-Date).ToString("yyyy-MM-dd")
$Type1Path = "$AuditBasePath\Type 1\$TodayDate"
$Type2Path = "$AuditBasePath\Type 2"  # Will be organized by Date-Range for the audit

# Create directories for Type 1 and Type 2 audits
$Type1Directories = @(
    "Security",
    "Availability",
    "Processing Integrity",
    "Confidentiality",
    "Privacy",
    "Unsorted"
)

foreach ($dir in $Type1Directories) {
    New-Item -Path "$Type1Path\$dir" -ItemType Directory -Force
}

# Function to fetch data from Splunk using the REST API
function Get-SplunkData {
    param (
        [string]$SplunkQuery,
        [string]$OutputPath
    )
    
    $splunkServer = "https://splunkserver.example.com:8089"
    $splunkAuthHeader = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:password"))  # Replace with your credentials

    # Make the API call
    $response = Invoke-RestMethod -Uri "$splunkServer/services/search/jobs" -Method Post -Headers @{ Authorization = $splunkAuthHeader } -Body @{ search = $SplunkQuery }
    
    # Process the response and export to CSV
    $response.results | Export-Csv -Path $OutputPath -NoTypeInformation
    
    Write-Host "Data fetched from Splunk and saved to $OutputPath"
}

# Function to sort data into the appropriate category based on the SOC 2 Trust Service Criteria
function SortAuditData {
    param (
        [string]$InputPath,
        [string]$BaseOutputPath
    )
    
    $data = Import-Csv -Path $InputPath
    foreach ($row in $data) {
        $targetPath = ""
        
        if ($row.EventCode -in @("4624", "4625", "4672")) {
            # Access-related events (Security)
            $targetPath = "$BaseOutputPath\Security"
        }
        elseif ($row.EventCode -in @("4647", "4657", "4740")) {
            # System configuration changes or availability-related (Processing Integrity or Availability)
            if ($row.EventCode -in @("4740")) {
                $targetPath = "$BaseOutputPath\Availability"
            } else {
                $targetPath = "$BaseOutputPath\Processing Integrity"
            }
        }
        elseif ($row.EventCode -in @("4670", "5136")) {
            # Data access or confidentiality-related (Confidentiality)
            $targetPath = "$BaseOutputPath\Confidentiality"
        }
        elseif ($row.EventCode -in @("5061", "5060")) {
            # Encryption and privacy-related events (Privacy)
            $targetPath = "$BaseOutputPath\Privacy"
        }
        else {
            # Any other events go to Unsorted
            $targetPath = "$BaseOutputPath\Unsorted"
        }
        
        $fileName = "$($row._time)__$($row.EventCode).csv"
        $row | Export-Csv -Path "$targetPath\$fileName" -NoTypeInformation -Append
    }
    
    Write-Host "Data sorted into respective categories based on SOC 2 Trust Service Criteria."
}

# Main script execution
New-Item -Path $AuditBasePath -ItemType Directory -Force

# Define Splunk queries for each SOC 2 category
$queries = @{
    "AccessLogs"        = "search index=main sourcetype=WinEventLog EventCode IN (4624,4625,4672,4647,4657,4740,4670,5136,5061,5060) | table _time, user, EventCode, ComputerName";
}

# Fetch and sort data for Type 1 audit
foreach ($category in $queries.Keys) {
    $outputPath = "$AuditBasePath\Unsorted\$category.csv"
    Get-SplunkData -SplunkQuery $queries[$category] -OutputPath $outputPath
    SortAuditData -InputPath $outputPath -BaseOutputPath $Type1Path
}

# The same approach can be followed for Type 2 by organizing the data into date ranges
# You can modify the date range in Splunk queries as per audit requirements

Write-Host "SOC 2 audit data processing complete. All data stored in $AuditBasePath"
