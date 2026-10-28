<#
.SYNOPSIS
    把 flutter build windows 的 Release 目录打成 per-user 安装的 .msi。

.DESCRIPTION
    逐文件枚举 SourceDir 生成 WiX v4/v5 源文件，再调用 wix build 出包。
    不使用 heat 通配符，避免不同 WiX 版本对 <Files Include> 的支持差异。

    安装位置：%LOCALAPPDATA%\Programs\<AppName>（无需管理员）
    附带：开始菜单快捷方式 + 卸载注册项（HKCU）

.EXAMPLE
    pwsh installer/build-msi.ps1 -SourceDir build/windows/x64/runner/Release `
        -Version 1.0.0 -Output dist/BJTUselfServiceAIO-1.0.0.msi
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Output,
    [string]$AppName = 'BJTUselfServiceAIO',
    [string]$Manufacturer = 'optsimauth',
    [string]$ExeName = 'bjtuselfserviceaio.exe',
    [string]$IconPath = '',
    [string]$UpgradeCode = 'DA7B158C-428A-4691-AC01-4159307920A1',
    [string]$ShortcutComponentGuid = '40482BD4-8F4B-4BA7-B571-5D130D01F21E'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }

function Norm-Id([string]$s) {
    # WiX 标识符只允许 [A-Za-z0-9_.]，且不能以数字开头
    $id = ($s -replace '[^A-Za-z0-9_.]', '_')
    if ($id -match '^[0-9]') { $id = "_$id" }
    return $id
}

$root = (Resolve-Path $SourceDir).Path
$exeFull = Join-Path $root $ExeName
if (-not (Test-Path -LiteralPath $exeFull)) {
    throw "找不到主程序 $exeFull，先跑 flutter build windows --release"
}

# MSI 的 ProductVersion 必须是纯数字 x.y.z，且每段 <= 65535
$msiVersion = ($Version -replace '[^0-9.]', '')
$parts = $msiVersion.Split('.') | Where-Object { $_ -ne '' }
if ($parts.Count -lt 2) { throw "版本号 $Version 无法转成 MSI ProductVersion" }
if ($parts.Count -eq 2) { $parts += '0' }
if ($parts.Count -gt 3) { $parts = $parts[0..2] }
$msiVersion = ($parts | Select-Object -First 3) -join '.'

# ---- 目录树 ----
$dirs = Get-ChildItem -LiteralPath $root -Directory -Recurse |
    ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/') }

$dirIdMap = @{}
$dirIndex = 0
foreach ($d in ($dirs | Sort-Object { ($_ -split '[\\/]').Count }, { $_ })) {
    $dirIdMap[$d] = 'Dir_' + $dirIndex
    $dirIndex++
}

# 按父子关系拼装 Directory 元素（嵌套深度用缩进表示）
$dirXml = New-Object System.Text.StringBuilder
$childrenByParent = @{}
foreach ($d in $dirIdMap.Keys) {
    $sep = if ($d.Contains('\')) { '\' } else { '/' }
    $idx = $d.LastIndexOfAny([char[]]@('\', '/'))
    $parent = if ($idx -lt 0) { '' } else { $d.Substring(0, $idx) }
    if (-not $childrenByParent.ContainsKey($parent)) { $childrenByParent[$parent] = @() }
    $childrenByParent[$parent] += $d
}

function Write-DirTree([string]$parentKey, [int]$depth) {
    $indent = '      ' + ('  ' * $depth)
    foreach ($d in ($childrenByParent[$parentKey] | Sort-Object)) {
        $leaf = ($d -split '[\\/]')[-1]
        [void]$dirXml.AppendLine("$indent<Directory Id=`"$($dirIdMap[$d])`" Name=`"$(Esc $leaf)`">")
        Write-DirTree $d ($depth + 1)
        [void]$dirXml.AppendLine("$indent</Directory>")
    }
}
Write-DirTree '' 0

# ---- 文件组件（一个文件一个 Component，避免 keypath 歧义）----
$compXml = New-Object System.Text.StringBuilder
$fileIndex = 0
foreach ($f in (Get-ChildItem -LiteralPath $root -File -Recurse | Sort-Object FullName)) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/')
    $idx = $rel.LastIndexOfAny([char[]]@('\', '/'))
    $parent = if ($idx -lt 0) { '' } else { $rel.Substring(0, $idx) }
    $dirId = if ($parent -eq '') { 'INSTALLFOLDER' } else { $dirIdMap[$parent] }
    $compId = 'Cmp_' + (Norm-Id $rel)
    [void]$compXml.AppendLine("    <Component Id=`"$compId`" Directory=`"$dirId`" Guid=`"*`">")
    [void]$compXml.AppendLine("      <File Id=`"Fil_$fileIndex`" Source=`"$(Esc $f.FullName)`" KeyPath=`"yes`" />")
    [void]$compXml.AppendLine('    </Component>')
    $fileIndex++
}

$iconXml = ''
if ($IconPath -and (Test-Path -LiteralPath $IconPath)) {
    $iconFull = (Resolve-Path $IconPath).Path
    $iconXml = "    <Icon Id=`"AppIcon`" SourceFile=`"$(Esc $iconFull)`" />`n    <Property Id=`"ARPPRODUCTICON`" Value=`"AppIcon`" />`n"
}

$wxs = @"
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
  <Package Name="$(Esc $AppName)" Manufacturer="$(Esc $Manufacturer)"
           Version="$msiVersion" UpgradeCode="$UpgradeCode"
           Scope="perUser" Language="1033">
    <MajorUpgrade DowngradeErrorMessage="已安装更新版本的 $(Esc $AppName)，请先从「应用和功能」卸载。" />
    <MediaTemplate EmbedCab="yes" />
$iconXml    <Feature Id="Main" Title="$(Esc $AppName)" Level="1">
      <ComponentGroupRef Id="AppFiles" />
      <ComponentRef Id="StartMenuShortcut" />
    </Feature>
  </Package>

  <Fragment>
    <StandardDirectory Id="LocalAppDataFolder">
      <Directory Id="ProgramsFolder" Name="Programs">
        <Directory Id="INSTALLFOLDER" Name="$(Esc $AppName)">
$dirXml        </Directory>
      </Directory>
    </StandardDirectory>
    <StandardDirectory Id="ProgramMenuFolder">
      <Directory Id="AppMenuFolder" Name="$(Esc $AppName)" />
    </StandardDirectory>

    <ComponentGroup Id="AppFiles">
$compXml    </ComponentGroup>
  </Fragment>

  <Fragment>
    <Component Id="StartMenuShortcut" Directory="AppMenuFolder" Guid="$ShortcutComponentGuid">
      <Shortcut Id="AppShortcut" Name="$(Esc $AppName)"
                Target="[INSTALLFOLDER]$(Esc $ExeName)" WorkingDirectory="INSTALLFOLDER" />
      <RemoveFolder Id="RemoveAppMenuFolder" Directory="AppMenuFolder" On="uninstall" />
      <RegistryValue Root="HKCU" Key="Software\$(Esc $Manufacturer)\$(Esc $AppName)"
                     Name="installed" Type="integer" Value="1" KeyPath="yes" />
    </Component>
  </Fragment>
</Wix>
"@

$outFull = [System.IO.Path]::GetFullPath($Output)
$outDir = Split-Path -Parent $outFull
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$wxsPath = Join-Path ([System.IO.Path]::GetTempPath()) ("$AppName-$([guid]::NewGuid().ToString('N')).wxs")
$wxs | Set-Content -LiteralPath $wxsPath -Encoding UTF8
Write-Host "WiX 源文件：$wxsPath（$fileIndex 个文件）"

try {
    wix build $wxsPath -o $outFull -arch x64
    if ($LASTEXITCODE -ne 0) { throw "wix build 失败，退出码 $LASTEXITCODE" }
} finally {
    Remove-Item -LiteralPath $wxsPath -Force -ErrorAction SilentlyContinue
}

Write-Host "已生成：$outFull"
