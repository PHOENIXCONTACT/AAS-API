# Subscription Key für die Phoenix Contact API – hier eintragen, um die interaktive Abfrage zu überspringen
$DefaultSubscriptionKey = ""

# Standard-Identification Link (IEC 61406), wie er als QR-Code auf dem Gerät aufgedruckt ist
$DefaultIdentificationLink = "https://i4d.de/a99fd6ef0b73b11d0a6cfde7c1ee76e8"

# Zielverzeichnis für heruntergeladene Dokumente
$DefaultOutputDirectory = "$env:USERPROFILE\Downloads\AAS-Dokumente"

function getSubscriptionKey {
    $subscription = ""
    do {
        $subscription = Read-Host "Please enter your subscription key"
        if ($subscription -eq "") {
            Write-Host "key cannot be null. Please enter a valid key"
        }
    } while ($subscription -eq "")
    return $subscription
}

function getIdentificationLink {
    $default = if ($DefaultIdentificationLink) { $DefaultIdentificationLink } else { "https://i4d.de/a99fd6ef0b73b11d0a6cfde7c1ee76e8" }
    $link = Read-Host "Please enter the identification link (default: $default)"
    if ($link -eq "") { $link = $default }
    return $link
}
