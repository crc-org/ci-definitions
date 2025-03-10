# Script to be executed on windows machine to build a crc windows installer
# and upload it to s3 compatible storage
param(
    [Parameter(HelpMessage='crc scm')]
    $crcSCM="https://github.com/code-ready/crc.git",
    [Parameter(HelpMessage='Optional parameter to build an specific PR for crc')]
    $crcSCMPR,
    [Parameter(HelpMessage='crc scm ref')]
    $crcSCMRef="main",
    [Parameter(HelpMessage='folder on the remote target to move all assets to run the builder')]
    $targetFolder="crc-builder",
    [Parameter(HelpMessage='upload path on remote storage where upload the artifacts')]
    $uploadPath,
    [Parameter(Mandatory,HelpMessage='url for remote s3 compatible storage where build bits will be stored')]
    $datalakeURL,
    [Parameter(Mandatory,HelpMessage='remote s3 credential ')]
    $datalakeAcessKey,
    [Parameter(Mandatory,HelpMessage='remote s3 credential')]
    $datalakeSecretKey,
    [Parameter(ValueFromRemainingArguments = $true)]
    $RemainingArgs
)

$ErrorActionPreference = "Stop"
# Upload content to S3 compatible
# $1 remote path
# $2 local path to be uploaded
function S3-Upload($uploadPath, $localPath) {
    
    .\mc.exe alias set datalake $datalakeURL `
        $datalakeAcessKey `
        $datalakeSecretKey `
        --api S3v4

    # Create bucket if not exits
    .\mc.exe mb "datalake/$uploadPath"
    # Copy files to datalake
    .\mc.exe cp "$localPath/crc-windows-installer.zip" "datalake/$uploadPath/crc-windows-installer.zip"
    .\mc.exe cp "$localPath/crc-windows-installer.zip.sha256sum" "datalake/$uploadPath/crc-windows-installer.zip.sha256sum"
    # Make bucket public
    # .\mc.exe anonymous set public "datalake/$uploadPath/"
}

function Get-UploadPath($crcVersion, $crcSCMPR, $crcSCMRef) {
    $path="distributables/app"
    if (([string]::IsNullOrEmpty($crcVersion))) {
        if (-not ([string]::IsNullOrEmpty($crcSCMPR))) {
            return "$path/pr-$crcSCMPR"
        } else {
            return "$path/$crcSCMRef"
        }
    } else {
        return "$path/release/$crcVersion"
    }
}

#######################
####### MAIN ##########
#######################

cd $targetFolder

# Custom setup for git
git config --global http.version "HTTP/1.1"
git config --global http.lowSpeedLimit 0      
git config --global http.lowSpeedTime 999999 

# Get crc code
git clone $crcSCM

pushd crc
# Fetch according to parameters provided
$crcVersionPartial=Get-Date -format "yy.MM.dd"
if ($PSBoundParameters.ContainsKey('crcSCMPR')) {
    git fetch origin pull/$crcSCMPR/head:pr-$crcSCMPR
    git checkout pr-$crcSCMPR
} else {
    git checkout $crcSCMRef
}
(Get-Content -path Makefile) `
        -replace 'CRC_VERSION = .*',"CRC_VERSION = $crcVersionPartial" `
        | Set-Content -path Makefile
popd

# Build admin-helper
git clone https://github.com/code-ready/admin-helper.git
$admin_version=$((cat admin-helper/crc-admin-helper.spec.in | Select-String -Pattern 'Version:') -split ':')[1].Trim()
make -C admin-helper out/windows-amd64/crc-admin-helper.exe VERSION=$admin_version

# Build win32-background-launcher
git clone https://github.com/crc-org/win32-background-launcher.git
$wbl_version=$((cat win32-background-launcher/Makefile | Select-String -Pattern 'VERSION :=') -split '=')[1].Trim()
make -C win32-background-launcher win32-background-launcher

# Build msi
pushd crc
mkdir custom_embedded
cp ./../admin-helper/out/windows-amd64/crc-admin-helper.exe custom_embedded/crc-admin-helper-windows.exe
cp ./../win32-background-launcher/bin/win32-background-launcher.exe custom_embedded/win32-background-launcher.exe

# Match admin-helper version with latest from master head
$content = Get-Content pkg/crc/version/version.go
$oldAdminHelperVersion = $content | Select-String "crcAdminHelperVersion " | Select-Object -ExpandProperty Line
$newAdminHelperVersion="crcAdminHelperVersion = `"$admin_version`""
$content -replace $oldAdminHelperVersion,$newAdminHelperVersion | Set-Content pkg/crc/version/version.go

# Match win32-background-launcher version with latest from master head
$content = Get-Content pkg/crc/version/version.go
$oldWBLVersion = $content | Select-String "win32BackgroundLauncherVersion " | Select-Object -ExpandProperty Line
$newWBLVersion="win32BackgroundLauncherVersion = `"$wbl_version`""
$content -replace $oldWBLVersion,$newWBLVersion | Set-Content pkg/crc/version/version.go

make out/windows-amd64/crc-windows-installer.zip CUSTOM_EMBED=true EMBED_DOWNLOAD_DIR=custom_embedded
popd

# Export
if (! $PSBoundParameters.ContainsKey('uploadPath')) {
    $uploadPath=Get-UploadPath $crcVersion $crcSCMPR $crcSCMRef
}
S3-Upload $uploadPath crc/out/windows-amd64 