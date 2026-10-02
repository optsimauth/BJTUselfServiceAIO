<#
  Coremail 会话探测（只读）。

  用法：
    1. 浏览器打开已登录的邮箱，把地址栏整条 URL 复制出来
    2. 从里面取出 sid= 后面那一串
    3. 执行：  pwsh -File tool/probe_mail.ps1 -Sid '<你的sid>'

  脚本只做「列表 / 详情」两个读操作，不会发信、不会删信。
  -IncludeCompose 为 true 时才会建草稿（写操作），默认关闭。
#>
param(
  [Parameter(Mandatory = $true)][string]$Sid,
  [switch]$IncludeCompose,
  [int]$Fid = 1,
  [int]$Limit = 2
)

$ErrorActionPreference = 'Continue'
$Jar = Join-Path $env:TEMP ("coremail_probe_{0}.txt" -f ($Sid.Substring(0, 8)))
Remove-Item $Jar -ErrorAction SilentlyContinue

$Origin   = 'https://mail.bjtu.edu.cn'
$IndexUrl = "$Origin/coremail/XT/index.jsp?sid=$Sid"
$JsonUrl  = "$Origin/coremail/s/json"
$Referer  = "$Origin/coremail/XT/index.jsp"

function Head($title) { Write-Output ""; Write-Output "=== $title ===" }

function Invoke-Coremail {
  param([string]$Url, [string]$Body, [switch]$Form)

  $headers = @(
    '-H', 'Accept: text/x-json',
    '-H', 'X-Requested-With: XMLHttpRequest',
    '-H', "Referer: $Referer"
  )
  if ($Body) {
    $headers += @('-H', 'Content-Type: text/x-json; tz="Asia/Shanghai"')
    if ($Form) {
      $headers += @('--data-raw', $Body)
    } else {
      $headers += @('--data-raw', $Body)
    }
  }
  & curl.exe -s -b $Jar -c $Jar @headers $Url
}

Head '1. 落地 index.jsp（种 cookie）'
$landing = & curl.exe -s -L -b $Jar -c $Jar -H "Referer: https://mis.bjtu.edu.cn/module/module/26/" $IndexUrl -w "`n__HTTP__%{http_code}`n__URL__%{url_effective}"
($landing -split "__HTTP__") | Select-Object -First 1 | Out-Null
Write-Output ($landing -split "`n" | Where-Object { $_ -like '__HTTP__*' -or $_ -like '__URL__*' })
Write-Output '--- 拿到的 cookie（值已隐藏）---'
if (Test-Path $Jar) {
  Get-Content $Jar | Select-String -NotMatch '^#' | Where-Object { $_.Trim() } |
    ForEach-Object {
      $p = $_ -split "`t"
      if ($p.Count -ge 7) { "  domain={0} path={1} name={2}" -f $p[0], $p[2], $p[5] }
    }
} else { Write-Output '  (没有 cookie jar)' }

Head '2. index.jsp 内嵌的 X 配置（判断会话是否活着）'
$html = & curl.exe -s -L -b $Jar -c $Jar -H "Referer: https://mis.bjtu.edu.cn/module/module/26/" $IndexUrl
if ($html -match 'var\s+\$?,\s*_,\s*X\s*=\s*(\{.*?\});') {
  Write-Output ("  " + ($Matches[1] -replace '\s+', ' '))
} else {
  Write-Output '  (没匹配到 X 配置，可能是崩溃页)'
}

Head "3. mbox:listMessages  fid=$Fid limit=$Limit"
$listBody = '{"start":0,"limit":' + $Limit + ',"mode":"count","order":"date","desc":true,"returnTotal":true,"returnTag":false,"summaryWindowSize":' + $Limit + ',"fid":' + $Fid + ',"mboxa":"","topFirst":true}'
$listRaw = Invoke-Coremail -Url "$JsonUrl?sid=$Sid&func=mbox:listMessages" -Body $listBody
Write-Output $listRaw

$mid = $null
try {
  $json = $listRaw | ConvertFrom-Json
  if ($json.code -ne 'S_OK') {
    Write-Output ("  >> code=$($json.code) —— 这就是登录失败的直接原因")
  } elseif ($json.var -and $json.var.Count -gt 0) {
    $mid = $json.var[0].id
    Write-Output ("  >> total=$($json.total) 首封 id=$mid")
  }
} catch { Write-Output '  (响应不是合法 JSON)' }

if ($mid) {
  Head "4. readMessage.jsp  mid=$mid"
  $detail = Invoke-Coremail -Url "$Origin/coremail/XT/jsp/readMessage.jsp" -Form `
    -Body ('mid=' + [uri]::EscapeDataString($mid) + '&mboxa=&part=&mailCipherPassword=')
  # 只打印结构，不打印正文
  try {
    $d = $detail | ConvertFrom-Json
    Write-Output ("  code=" + $d.code)
    Write-Output ("  mail 字段: " + (($d.var.mail.PSObject.Properties.Name) -join ', '))
    Write-Output ("  mailInfo 字段: " + (($d.var.mailInfo.PSObject.Properties.Name) -join ', '))
    $content = $d.var.mail.mainPartData.content
    if ($content) { Write-Output ("  正文长度: " + $content.Length + " 字符") }
  } catch { Write-Output $detail }
}

if ($IncludeCompose) {
  Head '5. compose.jsp  ctype=normal  （写操作：会建临时草稿）'
  $compose = Invoke-Coremail -Url "$Origin/coremail/XT/jsp/compose.jsp?sid=$Sid" -Form -Body 'ctype=normal&mboxa='
  try {
    $c = $compose | ConvertFrom-Json
    Write-Output ("  code=" + $c.code + "  草稿id=" + $c.var.id)
    if ($c.var.id) {
      Write-Output '  正在取消草稿...'
      Invoke-Coremail -Url "$JsonUrl?sid=$Sid&func=mbox:cancelComposes" -Body ('{"ids":"' + $c.var.id + '"}') | Out-Null
    }
  } catch { Write-Output $compose }
}

Head '完成'
Write-Output '把上面全部输出贴给我即可。'