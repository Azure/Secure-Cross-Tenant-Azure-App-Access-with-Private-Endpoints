#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Local Bicep validation script for developers
    
.DESCRIPTION
    This script validates all Bicep files in the deploy directory before committing.
    It checks for syntax errors, compilation issues, and basic best practices.
    
.EXAMPLE
    .\scripts\validate-bicep.ps1
    
.NOTES
    Requires Azure CLI with Bicep extension installed
#>

param(
    [switch]$Detailed,
    [switch]$SkipBestPractices
)

Write-Host "🔍 Starting Bicep validation..." -ForegroundColor Green

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "✅ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Error "❌ Azure CLI not found. Please install Azure CLI first."
    exit 1
}

# Check if Bicep is installed
try {
    $bicepVersion = az bicep version
    Write-Host "✅ Bicep version: $bicepVersion" -ForegroundColor Green
} catch {
    Write-Host "📥 Installing Bicep..." -ForegroundColor Yellow
    az bicep install
}

# Find all Bicep files
$bicepFiles = Get-ChildItem -Path "deploy" -Filter "*.bicep" -Recurse
Write-Host "📁 Found $($bicepFiles.Count) Bicep files to validate" -ForegroundColor Cyan

$errorCount = 0
$warningCount = 0

foreach ($file in $bicepFiles) {
    Write-Host "`n🔍 Validating: $($file.FullName)" -ForegroundColor Cyan
    
    # Test compilation
    try {
        $tempFile = [System.IO.Path]::GetTempFileName() + ".json"
        az bicep build --file $file.FullName --outfile $tempFile --output none
        
        if (Test-Path $tempFile) {
            Write-Host "  ✅ Syntax validation passed" -ForegroundColor Green
            Remove-Item $tempFile -Force
        }
    } catch {
        Write-Host "  ❌ Syntax validation failed: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
        continue
    }
    
    if (-not $SkipBestPractices) {
        # Basic best practices checks
        $content = Get-Content $file.FullName -Raw
        
        # Check for @description on parameters
        $paramLines = Select-String -Pattern "^\s*param\s+" -Path $file.FullName
        $descriptionLines = Select-String -Pattern "@description" -Path $file.FullName
        
        if ($paramLines.Count -gt $descriptionLines.Count) {
            Write-Host "  ⚠️  Some parameters missing @description decorator" -ForegroundColor Yellow
            $warningCount++
        }
        
        # Check for @secure() on sensitive parameters
        $sensitiveParams = Select-String -Pattern "param.*\b(?:password|secret|key)\b" -Path $file.FullName -CaseSensitive:$false
        foreach ($param in $sensitiveParams) {
            $lineNumber = $param.LineNumber
            $previousLine = (Get-Content $file.FullName)[$lineNumber - 2]
            
            if ($previousLine -notmatch "@secure") {
                Write-Host "  ⚠️  Sensitive parameter '$($param.Line.Trim())' should use @secure() decorator" -ForegroundColor Yellow
                $warningCount++
            }
        }
        
        # Check for hardcoded regions
        $hardcodedRegions = Select-String -Pattern "(?:eastus|westus|centralus|northeurope|westeurope)" -Path $file.FullName -CaseSensitive:$false
        if ($hardcodedRegions.Count -gt 0 -and $content -notmatch "param.*location") {
            Write-Host "  ⚠️  Potential hardcoded regions found" -ForegroundColor Yellow
            $warningCount++
        }
        
        Write-Host "  ✅ Best practices check completed" -ForegroundColor Green
    }
}

# Summary
Write-Host "`n📊 Validation Summary:" -ForegroundColor Cyan
Write-Host "  Files validated: $($bicepFiles.Count)" -ForegroundColor White
Write-Host "  Errors: $errorCount" -ForegroundColor $(if($errorCount -eq 0) { "Green" } else { "Red" })
Write-Host "  Warnings: $warningCount" -ForegroundColor $(if($warningCount -eq 0) { "Green" } else { "Yellow" })

if ($errorCount -gt 0) {
    Write-Host "`n❌ Validation failed with $errorCount error(s)" -ForegroundColor Red
    exit 1
} elseif ($warningCount -gt 0) {
    Write-Host "`n⚠️  Validation completed with $warningCount warning(s)" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n✅ All Bicep files validated successfully!" -ForegroundColor Green
    exit 0
}
