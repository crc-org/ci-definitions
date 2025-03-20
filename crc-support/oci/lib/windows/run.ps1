param(
    [Parameter(HelpMessage='download base url')]
    $aBaseURL,
    [Parameter(HelpMessage='asset name to be downloaded')]
    $aName,
    [Parameter(HelpMessage='shasumFile file name Default value: sha256sum.txt')]
    $aSHAName='sha256sum.txt',
    [Parameter(Mandatory,HelpMessage='target folder for download')]
    $targetPath,
    [Parameter(HelpMessage='force fresh, remove any previous existing instance for crc. Default False')]
    $freshEnv='false',
    [Parameter(HelpMessage='download if False not download. Default True')]
    $download='true',
    [Parameter(HelpMessage='delete the previous downloaded folders. Default False')]
    $delete='false',
    [Parameter(HelpMessage='install after downloading if False not install. Default False')]
    $install='false'
)

function Force-Fresh-Environment {
    if (Get-Command crc -errorAction SilentlyContinue)
	{
		crc cleanup

        # Wait to be cleared before uninstalling
        Pause-Until-Other-Installations-Finish
        pushd $latestPath
        Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/qb /x crc-windows-amd64.msi /norestart" -wait
        popd
	} 
    Start-Process powershell -Verb runAs -ArgumentList "Remove-Item -Recurse -Force $HOME\.crc"
    # Remove user from Hyper-V Administrator group
    Start-Process powershell -Verb runAs -ArgumentList "Remove-LocalGroupMember -SID S-1-5-32-578 -Member $(whoami)"
}

function Require-Download {
    if (!(Test-Path $aName)) {
        return $true
    }
    $hashValue=Get-FileHash $aName | Select-Object -ExpandProperty Hash
    $hashMatch=Select-String $aSHAName -Pattern $hashValue -Quiet
    return !$hashMatch
}

function Download ($binaryURL) {
    $isFinished=$false
    while(!$isFinished)
    {
        curl.exe --insecure -LO -C - $binaryURL
        $isFinished=$?
    }
}

function Check-Download() {
    $hashValue=Get-FileHash $aName | Select-Object -ExpandProperty Hash
    $hashMatch=Select-String $aSHAName -Pattern $hashValue -Quiet
    return $hashMatch
} 

function Pause-Until-Other-Installations-Finish() {
    do {
        try{
            $failed = $false
            $Mutex = [System.Threading.Mutex]::OpenExisting("Global\_MSIExecute");
            $Mutex.Dispose();
            Start-Sleep -Seconds 1
        } catch {
            $failed = $true
        }
    } while ($failed -eq $false)
}

##############
#### MAIN ####
##############


$latestPath="$HOME\OpenshiftLocal\crc\latest" 

# Transform params to bool
$install = If ($install -eq 'true') {$true} Else {$false}
$download = If ($download -eq 'true') {$true} Else {$false}
$freshEnv = If ($freshEnv -eq 'true') {$true} Else {$false}

# FORCE FRESH
if ($freshEnv) {
    Force-Fresh-Environment
}

New-Item -Path $targetPath -ItemType Directory -Force
pushd $targetPath

# DOWNLOAD
if ($download) {
    # Download sha256sum
    curl.exe --insecure -LO "$aBaseURL/$aSHAName"
    # Check if require download
    if (Require-Download $targetPath) {
        if (Test-Path $aName) {
            Remove-Item $aName
        }
        $distributableURL="$aBaseURL/$aName"
        Download $distributableURL
        $check=Check-Download
        if (!$check) {
            popd
            Write-Host "Error with downloaded binary"
            Exit
        }
    }
}

if ($delete) {
    cd ..
    ls
    Write-Host "removing 10 days ago folders "
    Get-ChildItem -Path . -Directory | Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-10))} | Remove-Item -Recurse -Force
    ls
    pushd $targetPath
}

# INSTALLATION
if ($install) {
    
    Write-Host "preparing crc installation"
    # Extract
    Expand-Archive -LiteralPath $aName -DestinationPath $targetPath -Force

    # Ensure current as latest, next time we want to force fresh this msi will be 
    # used to uninstall
    if (Test-Path $latestPath) { # Remove-Item fails if file does not exist
        Remove-Item -Path $latestPath -Force -Recurse
    }
    New-Item -Path $latestPath -ItemType Directory -Force
    Copy-Item -Path "$targetPath\*" -Destination $latestPath -Recurse

    # Waiting for other installers to finish
    Write-Host "waiting for other installations to finish"
    Pause-Until-Other-Installations-Finish
    # Install
    Write-Host "installing crc"
    Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/qb /i crc-windows-amd64.msi /norestart" -wait
    # Restart-Computer -Force
    # Run restart from powershell with privileges
    Write-Host "restarting host"
    Start-Process powershell -verb runas -ArgumentList "Restart-Computer -Force" -wait
    # Workaround on non required reboot contolled env
    #$Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

popd
