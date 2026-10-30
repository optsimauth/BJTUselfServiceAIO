<#
.SYNOPSIS
    把 flutter build windows 的 Release 目录打成可自选安装路径的 per-machine .msi。

.DESCRIPTION
    逐文件枚举 SourceDir 生成 WiX v4/v5 源文件，再调用 wix build 出包。

    安装形态（贴近常规 Windows 桌面软件）：
      - 默认安装到 %ProgramFiles%\<AppName>，安装向导里可「更改…」自选路径
      - 需要管理员权限（UAC 提权），写 HKLM，装到 Program Files
      - 安装向导：欢迎/许可协议 → 选择安装位置 → 安装进度 → 完成
      - 开始菜单快捷方式 + 桌面快捷方式（-NoDesktopShortcut 可关）
      - 记住上次选择的安装路径，升级时沿用
      - 控制面板「应用和功能」里显示图标、发布者、版本、大小、帮助链接

.EXAMPLE
    pwsh installer/build-msi.ps1 -SourceDir build/windows/x64/runner/Release `
        -Version 1.0.0 -Output dist/BJTUselfServiceAIO-1.0.0.msi
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourceDir,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Output,
    # 目录名 / 标识符用，保持 ASCII
    [string]$AppName = 'BJTUselfServiceAIO',
    # 显示名：快捷方式、应用和功能、安装向导标题
    [string]$DisplayName = '交大自由行 AIO',
    [string]$Manufacturer = 'optsimauth',
    [string]$ExeName = 'bjtuselfserviceaio.exe',
    [string]$IconPath = '',
    [string]$LicensePath = '',
    [string]$HelpUrl = 'https://github.com/optsimauth/BJTUselfServiceAIO',
    [switch]$NoDesktopShortcut,
    [string]$UpgradeCode = 'DA7B158C-428A-4691-AC01-4159307920A1',
    [string]$ShortcutComponentGuid = '40482BD4-8F4B-4BA7-B571-5D130D01F21E',
    [string]$DesktopShortcutComponentGuid = '9C1F5E2A-6B4D-4C39-8E7A-2D5B4F0C7A13'
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

# 把 UTF-8 文本转成 RTF（非 ASCII 字符走 \uNNNN? ，不依赖代码页）
function ConvertTo-Rtf([string]$text) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('{\rtf1\ansi\ansicpg1252\deff0{\fonttbl{\f0\fnil\fcharset134 SimSun;}}')
    [void]$sb.Append("`r`n\fs20 ")
    foreach ($ch in $text.ToCharArray()) {
        $code = [int]$ch
        if ($ch -eq '`r') {
            continue
        }
        elseif ($ch -eq "`n") {
            [void]$sb.Append('\par' + "`r`n")
        }
        elseif ($ch -eq '\') {
            [void]$sb.Append('\\')
        }
        elseif ($ch -eq '{') {
            [void]$sb.Append('\{')
        }
        elseif ($ch -eq '}') {
            [void]$sb.Append('\}')
        }
        elseif ($code -lt 128) {
            [void]$sb.Append($ch)
        }
        else {
            if ($code -gt 32767) { $code -= 65536 }
            [void]$sb.Append("\u${code}?")
        }
    }
    [void]$sb.Append('}')
    return $sb.ToString()
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
    $idx = $d.LastIndexOfAny([char[]]@('\', '/'))
    $parent = if ($idx -lt 0) { '' } else { $d.Substring(0, $idx) }
    if (-not $childrenByParent.ContainsKey($parent)) { $childrenByParent[$parent] = @() }
    $childrenByParent[$parent] += $d
}

function Write-DirTree([string]$parentKey, [int]$depth) {
    $indent = '          ' + ('  ' * $depth)
    if (-not $childrenByParent.ContainsKey($parentKey)) { return }
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
    if ($compId.Length -gt 60) {
        # 标识符超长时改用相对路径的哈希，保持稳定（升级时可正常引用）
        $sha = [System.Security.Cryptography.SHA1]::Create()
        $hash = [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($rel))).Replace('-', '')
        $compId = 'Cmp_h_' + $hash.Substring(0, 16).ToLowerInvariant()
    }
    [void]$compXml.AppendLine("    <Component Id=`"$compId`" Directory=`"$dirId`" Guid=`"*`">")
    [void]$compXml.AppendLine("      <File Id=`"Fil_$fileIndex`" Source=`"$(Esc $f.FullName)`" KeyPath=`"yes`" />")
    [void]$compXml.AppendLine('    </Component>')
    $fileIndex++
}

# 图标：优先用传入的 .ico，否则直接从 exe 里取（WiX 支持从 PE 提取图标）
$iconSource = ''
if ($IconPath -and (Test-Path -LiteralPath $IconPath)) {
    $iconSource = (Resolve-Path $IconPath).Path
}
else {
    $iconSource = $exeFull
}
$iconXml = "    <Icon Id=`"AppIcon`" SourceFile=`"$(Esc $iconSource)`" />`n    <Property Id=`"ARPPRODUCTICON`" Value=`"AppIcon`" />`n"

# 许可协议 RTF：WixUI_InstallDir 的欢迎页带「我接受」，没有它构建会报错
$licenseTxt = if ($LicensePath -and (Test-Path -LiteralPath $LicensePath)) {
    (Resolve-Path $LicensePath).Path
}
else {
    Join-Path $PSScriptRoot 'license.txt'
}
if (-not (Test-Path -LiteralPath $licenseTxt)) { throw "缺少许可协议文本 $licenseTxt" }
$licenseRtf = Join-Path ([System.IO.Path]::GetTempPath()) ("$AppName-license-$([guid]::NewGuid().ToString('N')).rtf")
ConvertTo-Rtf (Get-Content -LiteralPath $licenseTxt -Raw -Encoding UTF8) |
    Set-Content -LiteralPath $licenseRtf -Encoding ASCII -NoNewline

$desktopFeatureRef = if ($NoDesktopShortcut) { '' } else { "      <ComponentRef Id=`"DesktopShortcut`" />`n" }
$desktopComponent = if ($NoDesktopShortcut) { '' } else {
@"
  <Fragment>
    <Component Id="DesktopShortcut" Directory="DesktopFolder" Guid="$DesktopShortcutComponentGuid">
      <Shortcut Id="DesktopAppShortcut" Name="$(Esc $DisplayName)"
                Target="[INSTALLFOLDER]$(Esc $ExeName)" WorkingDirectory="INSTALLFOLDER"
                Icon="AppIcon" />
      <RegistryValue Root="HKLM" Key="Software\$(Esc $Manufacturer)\$(Esc $AppName)"
                     Name="desktopShortcut" Type="integer" Value="1" KeyPath="yes" />
    </Component>
  </Fragment>

"@
}

$wxs = @"
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs"
     xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui">
  <Package Name="$(Esc $DisplayName)" Manufacturer="$(Esc $Manufacturer)"
           Version="$msiVersion" UpgradeCode="$UpgradeCode"
           Scope="perMachine" Language="2052" InstallerVersion="500">

    <!-- 主版本升级：覆盖安装，保留自定义安装目录 -->
    <MajorUpgrade DowngradeErrorMessage="已安装更新版本的 $(Esc $DisplayName)，请先卸载后再安装旧版。"
                  Schedule="afterInstallInitialize" />

    <MediaTemplate EmbedCab="yes" CompressionLevel="high" />

    <!-- 安装位置：默认 Program Files，用户可在向导里更改；升级时沿用上次路径 -->
    <Property Id="INSTALLFOLDER">
      <RegistrySearch Id="PrevInstallDir" Root="HKLM" Key="Software\$(Esc $Manufacturer)\$(Esc $AppName)"
                      Name="InstallDir" Type="raw" />
    </Property>
    <Property Id="ARPCONTACT" Value="$(Esc $Manufacturer)" />
    <Property Id="ARPCOMMENTS" Value="北京交通大学校园服务客户端（Flutter 重写版）" />
    <Property Id="ARPHELPLINK" Value="$(Esc $HelpUrl)" />
    <Property Id="ARPURLINFOABOUT" Value="$(Esc $HelpUrl)" />
$iconXml
    <WixVariable Id="WixUILicenseRtf" Value="$(Esc $licenseRtf)" />

    <ui:WixUI Id="WixUI_InstallDir" InstallDirectory="INSTALLFOLDER" />

    <Feature Id="Main" Title="$(Esc $DisplayName)" Level="1"
             Description="主程序、运行库与开始菜单快捷方式">
      <ComponentGroupRef Id="AppFiles" />
      <ComponentRef Id="InstallLocationRegistry" />
      <ComponentRef Id="StartMenuShortcut" />
$desktopFeatureRef    </Feature>
  </Package>

  <Fragment>
    <StandardDirectory Id="ProgramFiles64Folder">
      <Directory Id="INSTALLFOLDER" Name="$(Esc $AppName)">
$dirXml      </Directory>
    </StandardDirectory>
    <StandardDirectory Id="ProgramMenuFolder">
      <Directory Id="AppMenuFolder" Name="$(Esc $DisplayName)" />
    </StandardDirectory>
  </Fragment>

  <Fragment>
    <ComponentGroup Id="AppFiles">
$compXml    </ComponentGroup>
  </Fragment>

  <Fragment>
    <!-- 记住用户选的安装目录，下次升级/修复时复用 -->
    <Component Id="InstallLocationRegistry" Directory="INSTALLFOLDER" Guid="*">
      <RegistryValue Root="HKLM" Key="Software\$(Esc $Manufacturer)\$(Esc $AppName)"
                     Name="InstallDir" Type="string" Value="[INSTALLFOLDER]" KeyPath="yes" />
    </Component>
  </Fragment>

  <Fragment>
    <Component Id="StartMenuShortcut" Directory="AppMenuFolder" Guid="$ShortcutComponentGuid">
      <Shortcut Id="AppShortcut" Name="$(Esc $DisplayName)"
                Target="[INSTALLFOLDER]$(Esc $ExeName)" WorkingDirectory="INSTALLFOLDER"
                Icon="AppIcon" Description="$(Esc $DisplayName)" />
      <RemoveFolder Id="RemoveAppMenuFolder" Directory="AppMenuFolder" On="uninstall" />
      <RegistryValue Root="HKLM" Key="Software\$(Esc $Manufacturer)\$(Esc $AppName)"
                     Name="installed" Type="integer" Value="1" KeyPath="yes" />
    </Component>
  </Fragment>

$desktopComponent</Wix>
"@

$outFull = [System.IO.Path]::GetFullPath($Output)
$outDir = Split-Path -Parent $outFull
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$wxsPath = Join-Path ([System.IO.Path]::GetTempPath()) ("$AppName-$([guid]::NewGuid().ToString('N')).wxs")
$wxs | Set-Content -LiteralPath $wxsPath -Encoding UTF8
Write-Host "WiX 源文件：$wxsPath（$fileIndex 个文件）"

try {
    wix build $wxsPath -o $outFull -arch x64 -culture zh-CN -ext WixToolset.UI.wixext
    if ($LASTEXITCODE -ne 0) { throw "wix build 失败，退出码 $LASTEXITCODE" }
}
finally {
    Remove-Item -LiteralPath $wxsPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $licenseRtf -Force -ErrorAction SilentlyContinue
}

Write-Host "已生成：$outFull"
