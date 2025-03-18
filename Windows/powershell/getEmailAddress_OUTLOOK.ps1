
# This script extracts email addresses from a specified Outlook folder and saves the results to a text file.

$USERPROFILE = [System.Environment]::GetEnvironmentVariable("USERPROFILE")

# Parent folder is usually the email address of the user when the folders are not within the inbox folder
$PARENT_FOLDER = ""
$OUTLOOK_FOLDER_NAME = "Qt License"
$outputFile = "${USERPROFILE}\Downloads\email_addresses.txt"
$EXCLUDED_EMAILS = @()



Add-Type -AssemblyName Microsoft.Office.Interop.Outlook
$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")

$folderObj = $namespace.Folders[$PARENT_FOLDER].Folders[$OUTLOOK_FOLDER_NAME]
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Get emails
$emails = $folderObj.Items
$allAddresses = @()
$emailCount = 0

foreach ($email in $emails) {
    $emailCount++

    # METHOD 2: Use Recipients collection as backup
    if ($email.Recipients) {
        foreach ($recipient in $email.Recipients) {
            $address = $null
            try {
                if ($recipient.AddressEntry.GetExchangeUser()) {
                    $address = $recipient.AddressEntry.GetExchangeUser().PrimarySmtpAddress
                } 
                elseif ($recipient.Address) {
                    $address = $recipient.Address
                }

                if ($address -in $EXCLUDED_EMAILS) {
                    continue
                } elseif ($address) {
                    $allAddresses += $address
                }
            } catch {
                Write-Host "  Error getting address: $_" -ForegroundColor Red
            }
        }
    }
}

# Count occurrences of each email address
$addressCounts = @{}
foreach ($address in $allAddresses) {
    if ($addressCounts.ContainsKey($address)) {
        $addressCounts[$address]++
    } else {
        $addressCounts[$address] = 1
    }
}

# Sort the results by count (descending)
$sortedAddresses = $addressCounts.GetEnumerator() | Sort-Object -Property Value -Descending

# Create the output file with header
"Email Addresses Extracted from Outlook Folder '$OUTLOOK_FOLDER_NAME'" | Out-File -FilePath $outputFile
"Extraction Date: $timestamp" | Out-File -FilePath $outputFile -Append
"Total Emails Processed: $emailCount" | Out-File -FilePath $outputFile -Append
"Unique Email Addresses Found: $($addressCounts.Count)" | Out-File -FilePath $outputFile -Append
"" | Out-File -FilePath $outputFile -Append
"COUNT - EMAIL ADDRESS" | Out-File -FilePath $outputFile -Append
"----------------------------------------" | Out-File -FilePath $outputFile -Append

# Write the counts and addresses
foreach ($entry in $sortedAddresses) {
    "$($entry.Value) - $($entry.Key)" | Out-File -FilePath $outputFile -Append
}

# Display summary
Write-Host "Processed $emailCount emails"
Write-Host "Found $($allAddresses.Count) total email addresses"
Write-Host "Found $($addressCounts.Count) unique email addresses"
Write-Host "Results saved to: '$outputFile'"