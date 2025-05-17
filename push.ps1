param(
    [Parameter(Mandatory=$true)]
    [string]$message
)

# Add all changes
git add .

# Commit with the provided message
git commit -m $message

# Push to main
git push origin main

Write-Host "Changes pushed to main successfully!" -ForegroundColor Green 