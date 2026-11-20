# ScanPilot demo for Windows. Same steps as demo.sh, but needs no python or zip.
#   .\demo.ps1                      full run, ends DONE
#   .\demo.ps1 -Fail sast           SAST keeps failing, ends FAILED
#   .\demo.ps1 -Mode sast_only      SAST, triage and report only
param(
  [string]$Mode = "full",
  [string]$Fail = "none",
  [string]$Target = "test-target.scanpilot.local"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$key = if ($env:SCANPILOT_KEY) { $env:SCANPILOT_KEY } else { "sp-demo-key-123" }
$headers = @{ "x-api-key" = $key }
$api = terraform output -raw api_url
if ($LASTEXITCODE -ne 0) { throw "could not read api_url, run terraform apply first" }

Write-Host "== 1. Create job (mode=$Mode, force_fail_step=$Fail, target=$Target)"
$body = @{ mode = $Mode; force_fail_step = $Fail; target = $Target } | ConvertTo-Json
$job = Invoke-RestMethod -Method Post -Uri "$api/jobs" -Headers $headers -ContentType "application/json" -Body $body
Write-Host "   job_id: $($job.job_id)"

Write-Host "== 2. Zip sample-app and upload it with the pre-signed URL"
New-Item -ItemType Directory -Force build | Out-Null
$zip = Join-Path $PSScriptRoot "build\sample-app.zip"
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $PSScriptRoot "sample-app"), $zip)
$upload = Invoke-WebRequest -Method Put -Uri $job.upload_url -InFile $zip -UseBasicParsing
Write-Host "   upload HTTP $($upload.StatusCode)"

Write-Host "== 3. Poll GET /jobs/$($job.job_id)"
$last = ""
for ($i = 0; $i -lt 480; $i++) {
  $status = Invoke-RestMethod -Uri "$api/jobs/$($job.job_id)" -Headers $headers
  if ($status.status -ne $last) {
    Write-Host ("   {0}  {1}" -f (Get-Date -Format "HH:mm:ss"), $status.status)
    $last = $status.status
  }
  if ($status.status -in "DONE", "PARTIAL", "FAILED") { break }
  Start-Sleep -Milliseconds 500
}

Write-Host "== 4. Final job record"
if ($status.sast_summary) {
  $s = $status.sast_summary
  Write-Host "   SAST: $($s.filesScanned) files, $($s.totalVulnerabilities) findings ($($s.high) high, $($s.medium) medium, $($s.low) low)"
}
if ($status.report_url) {
  $status.report_url = "(pre-signed S3 link, valid 15 min)"
}
$status | ConvertTo-Json -Depth 5
