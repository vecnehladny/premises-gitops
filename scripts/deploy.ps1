param (
    $cluster,
    $namespace,
    $installFlux = $true
)

if (-not $cluster) {
    $cluster = "localhost"
}

if (-not $namespace) {
    $namespace = "wac-hospital"
}

$ProjectRoot = "$PSScriptRoot\.."
Write-Host "ScriptRoot is $PSScriptRoot"
Write-Host "ProjectRoot is $ProjectRoot"

$clusterRoot = "$ProjectRoot\clusters\$cluster"

$ErrorActionPreference = "Stop"

$context = kubectl config current-context

if ((Get-Host).version.major -lt 5) {
    Write-Host -ForegroundColor Red "PowerShell Version must be minimum of 5, please install PowerShell 5. Current Version is $((Get-Host).version)"
    exit -10
}
$pwsv = (Get-Host).version

# Check if $cluster folder exists
if (-not (Test-Path -Path "$clusterRoot" -PathType Container)) {
    Write-Host -ForegroundColor Red "Cluster folder $cluster does not exist"
    exit -12
}

Write-Host "THIS IS A FAST DEPLOYMENT SCRIPT FOR DEVELOPERS!
---

The script shall be running only on fresh local cluster!
After initialization, it uses gitops controlled by installed flux cd controller.
To do some local fine tuning get familiarized with flux, kustomize, and kubernetes

Verify that your context is corresponding to your local development cluster:

* Your kubectl context is $context.
* You are installing cluster $cluster.
* PowerShell version is $pwsv."

$correct = Read-Host "Are you sure to continue? (y/n)"

if ($correct -ne 'y') {
    Write-Host -ForegroundColor Red "Exiting script due to the user selection"
    exit -1
}

# Create a namespace
Write-Host -ForegroundColor Blue "Creating namespace $namespace"
kubectl create namespace $namespace
Write-Host -ForegroundColor Green "Created namespace $namespace"

Write-Host -ForegroundColor Blue "Applying repository-pat secret"
kubectl apply -f "$clusterRoot\secrets\repository-pat.yaml" -n $namespace
Write-Host -ForegroundColor Green "Created repository-pat secret in the namespace $namespace"

if ($installFlux) {
    Write-Host -ForegroundColor Blue "Deploying the Flux CD controller"
    # First ensure crds exists when applying the repos
    kubectl apply -k "$ProjectRoot\infrastructure\fluxcd" --wait

    if ($LASTEXITCODE -ne 0) {
        Write-Host -ForegroundColor Red "Failed to deploy fluxcd"
        exit -15
    }

    Write-Host -ForegroundColor Blue "Flux CD controller deployed"
}

Write-Host -ForegroundColor Blue "Deploying the cluster manifests"
kubectl apply -k "$clusterRoot" --wait
Write-Host -ForegroundColor Green "Bootstrapping process is done, check the status of the GitRepository and Kustomization resource in namespace $namespace for reconciliation updates"
