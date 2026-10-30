[cmdletbinding()]
param(
    [switch]$includerecyclebin,
    [switch]$deep = $true
)

$erroractionpreference = "silentlycontinue"
$progresspreference = "silentlycontinue"
$warningpreference = "silentlycontinue"

function test-admin {
    $identity = [security.principal.windowsidentity]::getcurrent()
    $principal = [security.principal.windowsprincipal]::new($identity)
    return $principal.isinrole([security.principal.windowsbuiltinrole]::administrator)
}

$scriptpath = if ($pscommandpath) { $pscommandpath } else { $myinvocation.mycommand.path }
if (-not (test-admin)) {
    try {
        if ($scriptpath) {
            $forwardargs = @("-nologo", "-noprofile", "-executionpolicy", "bypass", "-file", "`"$scriptpath`"")
            if ($includerecyclebin) { $forwardargs += "-includerecyclebin" }
            if (-not $deep) { $forwardargs += "-deep:`$false" }
            start-process powershell.exe -argumentlist ($forwardargs -join " ") -verb runas -erroraction stop
        } else {
            $cmd = "irm https://raw.githubusercontent.com/snipe1337/ryze-cache/main/ryze-cache-cleaner.ps1 | iex"
            start-process powershell.exe -argumentlist "-nologo -noprofile -executionpolicy bypass -command `"$cmd`"" -verb runas -erroraction stop
        }
    } catch {}
    exit
}

function write-section([string]$text) {
    write-host ""
    write-host "  :: $text" -foregroundcolor darkcyan
}

function get-directorysize([string]$path) {
    if (-not (test-path -literalpath $path)) { return [int64]0 }
    $sum = [int64]0
    get-childitem -literalpath $path -force -file -recurse -erroraction silentlycontinue |
        foreach-object { $sum += $_.length }
    return $sum
}

function clear-directorycontents([string]$path, [string]$label) {
    if (-not (test-path -literalpath $path)) { return }
    $before = get-directorysize $path
    get-childitem -literalpath $path -force -erroraction silentlycontinue |
        foreach-object {
            try {
                remove-item -literalpath $_.fullname -recurse -force -erroraction stop
            } catch {}
        }
    $after = get-directorysize $path
    $script:reclaimed += [math]::max([int64]0, ($before - $after))
    write-host ("    {0,-28} {1}" -f $label, (format-bytes ($before - $after))) -foregroundcolor darkgray
}

function clear-filepattern([string]$path, [string]$filter, [string]$label) {
    if (-not (test-path -literalpath $path)) { return }
    $files = get-childitem -literalpath $path -filter $filter -file -force -erroraction silentlycontinue
    $freed = [int64]0
    foreach ($file in $files) {
        $length = $file.length
        try {
            remove-item -literalpath $file.fullname -force -erroraction stop
            $freed += $length
        } catch {}
    }
    $script:reclaimed += $freed
    write-host ("    {0,-28} {1}" -f $label, (format-bytes $freed)) -foregroundcolor darkgray
}

function format-bytes([double]$bytes) {
    if ($bytes -ge 1tb) { return "{0:n2} tb" -f ($bytes / 1tb) }
    if ($bytes -ge 1gb) { return "{0:n2} gb" -f ($bytes / 1gb) }
    if ($bytes -ge 1mb) { return "{0:n2} mb" -f ($bytes / 1mb) }
    if ($bytes -ge 1kb) { return "{0:n2} kb" -f ($bytes / 1kb) }
    return "$([math]::max(0, [int64]$bytes)) b"
}

$script:reclaimed = [int64]0
$local = $env:localappdata

clear-host
write-host ""
write-host "  ryze cache cleaner" -foregroundcolor cyan
write-host "  credits: ryze [snipe1337] on github" -foregroundcolor darkgray
write-host ""

$confirm = read-host "  press enter to clean (or q to quit)"
if ($confirm -in @("q", "quit", "exit", "n")) {
    write-host "  cancelled." -foregroundcolor darkgray
    exit
}

write-section "temp files"
clear-directorycontents $env:temp "user temp"
clear-directorycontents (join-path $local "temp") "local app temp"

write-section "system temp"
clear-directorycontents "$env:windir\temp" "windows temp"
clear-directorycontents "$env:windir\minidump" "crash minidumps"
clear-filepattern "$env:windir" "memory.dmp" "system memory dump"
clear-filepattern "$env:windir\logs\cbs" "cbspersist_*.log" "cbs persist logs"
clear-filepattern "$env:windir\logs\cbs" "*.cab" "cbs persist cabs"

write-section "diagnostics & drivers"
clear-directorycontents "$local\microsoft\windows\wer\reportarchive" "user wer reports"
clear-directorycontents "$local\microsoft\windows\wer\reportqueue" "user wer queue"
clear-directorycontents "$env:programdata\microsoft\windows\wer\reportarchive" "system wer reports"
clear-directorycontents "$env:programdata\microsoft\windows\wer\reportqueue" "system wer queue"
clear-directorycontents "c:\nvidia\displaydriver" "nvidia driver installer"
clear-directorycontents "c:\amd" "amd driver installer"

write-section "windows update"
$services = @("wuauserv", "bits", "dosvc")
foreach ($service in $services) {
    stop-service -name $service -force -erroraction silentlycontinue -warningaction silentlycontinue
}
clear-directorycontents "$env:windir\softwaredistribution\download" "windows update downloads"
clear-directorycontents "$env:programdata\microsoft\windows\deliveryoptimization\cache" "delivery optimization"
foreach ($service in $services) {
    start-service -name $service -erroraction silentlycontinue -warningaction silentlycontinue
}

write-section "graphics & explorer"
$cachepaths = @(
    @{ path = "$local\d3dscache"; label = "directx shader cache" },
    @{ path = "$local\nvidia\dxcache"; label = "nvidia dxcache" },
    @{ path = "$local\nvidia\glcache"; label = "nvidia glcache" },
    @{ path = "$local\nvidia corporation\nv_cache"; label = "nvidia nv cache" },
    @{ path = "$local\amd\dxcache"; label = "amd dxcache" },
    @{ path = "$local\amd\glcache"; label = "amd glcache" },
    @{ path = "$local\microsoft\windows\explorer"; label = "explorer caches" }
)
foreach ($entry in $cachepaths) {
    if ($entry.label -eq "explorer caches") {
        clear-filepattern $entry.path "thumbcache_*.db" "explorer thumbnails"
        clear-filepattern $entry.path "iconcache_*.db" "explorer icons"
    } else {
        clear-directorycontents $entry.path $entry.label
    }
}

write-section "browsers"
$browsercachepaths = @(
    @{ path = "$local\google\chrome\user data\default\cache"; label = "chrome default cache" },
    @{ path = "$local\google\chrome\user data\default\code cache"; label = "chrome code cache" },
    @{ path = "$local\google\chrome\user data\default\gpucache"; label = "chrome gpu cache" },
    @{ path = "$local\microsoft\edge\user data\default\cache"; label = "edge default cache" },
    @{ path = "$local\microsoft\edge\user data\default\code cache"; label = "edge code cache" },
    @{ path = "$local\microsoft\edge\user data\default\gpucache"; label = "edge gpu cache" },
    @{ path = "$local\opera software\opera stable\cache"; label = "opera cache" },
    @{ path = "$local\opera software\opera stable\code cache"; label = "opera code cache" },
    @{ path = "$local\opera software\opera stable\gpucache"; label = "opera gpu cache" }
)
foreach ($entry in $browsercachepaths) {
    clear-directorycontents $entry.path $entry.label
}

$chromiumroots = @(
    "$local\google\chrome\user data",
    "$local\microsoft\edge\user data"
)
foreach ($root in $chromiumroots) {
    if (test-path -literalpath $root) {
        get-childitem -literalpath $root -directory -erroraction silentlycontinue |
            where-object { $_.name -eq "default" -or $_.name -match '^profile \d+$' } |
            foreach-object {
                foreach ($name in @("cache", "code cache", "gpucache")) {
                    clear-directorycontents (join-path $_.fullname $name) ("{0} {1}" -f $_.name.tolower(), $name)
                }
            }
    }
}

write-section "media & games"
clear-directorycontents "$local\spotify\data" "spotify cache"
clear-directorycontents "$local\spotify\storage" "spotify storage"
clear-directorycontents "$local\steam\htmlcache" "steam web cache"
clear-directorycontents "$local\epicgameslauncher\saved\webcache" "epic games web cache"
clear-directorycontents "$local\battle.net\browserdb" "battle.net web cache"

write-section "discord"
$discordroots = @(
    "$local\discord",
    "$local\discordcanary",
    "$local\discordptb"
)
foreach ($root in $discordroots) {
    foreach ($name in @("cache", "code cache", "gpucache")) {
        clear-directorycontents (join-path $root $name) ("{0} {1}" -f (split-path $root -leaf).tolower(), $name)
    }
}

write-section "app caches"
$othercaches = @(
    @{ path = "$local\crashdumps"; label = "user crash dumps" },
    @{ path = "$local\microsoft\windows\inetcache"; label = "windows internet cache" }
)
foreach ($entry in $othercaches) {
    clear-directorycontents $entry.path $entry.label
}

if ($deep) {
    write-section "developer & deep caches"
    clear-directorycontents "$local\packages\microsoft.windowsstore_8wekyb3d8bbwe\localcache" "microsoft store cache"
    clear-directorycontents "$local\pip\cache" "pip cache"
    clear-directorycontents "$local\npm-cache" "npm cache"
    clear-directorycontents "$local\yarn\cache" "yarn cache"
    clear-directorycontents "$local\nuget\v3-cache" "nuget cache"
    clear-directorycontents "$local\go-build" "go build cache"
    clear-directorycontents "$env:appdata\code\cache" "vscode cache"
    clear-directorycontents "$env:appdata\code\cacheddata" "vscode code cache"
    clear-directorycontents "$env:appdata\code\gpucache" "vscode gpu cache"
    clear-directorycontents "$env:userprofile\.cargo\registry\cache" "cargo registry cache"
    clear-directorycontents "$env:userprofile\.gradle\caches" "gradle cache"
}

if ($includerecyclebin) {
    write-section "recycle bin"
    $answer = read-host "  empty recycle bin? (y/n)"
    if ($answer -in @("y", "yes")) {
        try {
            clear-recyclebin -force -erroraction stop
            write-host "    recycle bin emptied" -foregroundcolor darkgray
        } catch {
            write-host "    skipped" -foregroundcolor darkgray
        }
    } else {
        write-host "    skipped" -foregroundcolor darkgray
    }
}

write-host ""
write-host "  reclaimed: $(format-bytes $script:reclaimed)" -foregroundcolor cyan
write-host "  done." -foregroundcolor darkgray
write-host ""
[void](read-host "  press enter to exit")
