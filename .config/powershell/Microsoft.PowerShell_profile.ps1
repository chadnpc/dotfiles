# ----- Set encoding to UTF-8 -----
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding
#Requires -RunAsAdministrator
#Requires -Modules cliHelper.env, Terminal-Icons, posh-git, PowerType, PSReadLine
#Requires -Psedition Core

$omp_config = "$PSScriptRoot/alain.omp.json"
$pwshconfig = "$PSScriptRoot/powershell.config.json"
$local:_cfg = $(if ([IO.File]::Exists($pwshconfig)) {
    [IO.File]::ReadAllText($pwshconfig) | ConvertFrom-Json
  } else {
    [PsObject]::new()
  }
)

# ReadLine suggestions
Enable-PowerType
Set-PSReadLineOption -BellStyle None
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -Colors @{ InlinePrediction = '#2F7004' }
Set-PSReadLineOption -PredictionViewStyle ListView

Set-PSReadLineKeyHandler -Key Ctrl+Shift+b `
  -BriefDescription BuildCurrentDirectory `
  -LongDescription "Build the current directory" `
  -ScriptBlock {
  [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
  [Microsoft.PowerShell.PSConsoleReadLine]::Insert("dotnet build")
  [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
# -----  Fzf -----
if (!$IsWindows) {
  Import-Module PSFzf -Verbose:$false
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# winget install ajeetdsouza.zoxide

# ----- Environment variables -----
if ($IsWindows) {
  Set-Env GIT_SSH -Scope Machine -Value "C:\Windows\system32\OpenSSH\ssh.exe"
  Set-Env GIT_SSH_COMMAND -Scope Machine -Value "C:\Windows\system32\OpenSSH\ssh.exe -o ControlMaster=auto -o ControlPersist=60s"
}
Set-Env PATH -Scope Machine -Value ([string]::Join([IO.Path]::PathSeparator, ${env:PATH}, [IO.Path]::Combine(${HOME}, ".dotnet/tools")))

# ----- Aliases -----
Set-Alias v nvim
Set-Alias l Get-ChildItem
Set-Alias ls Get-ChildItem
Set-Alias g git
Set-Alias lg lazygit
Set-Alias ld lazydocker
Set-Alias code cursor
Set-Alias fetch fastfetch
Set-Alias c clear
Set-Alias nf fastfetch
Set-Alias ff fastfetch
Set-Alias wifi nmtui
Set-Alias files nautilus

if ($IsWindows) {
  Set-Alias grep findstr
  Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'
  Set-Alias less 'C:\Program Files\Git\usr\bin\less.exe'
}

# ----- Functions -----
function ll { eza -al --icons=always }
function gs { git status }
function ga { git add }
function gcom { git commit -m }
function gpush { git push }
function gpull { git pull }
function gst { git stash }
function gsp { git stash; git pull }
function gfo { git fetch origin }
function gcheck { git checkout }
function cleanup { sh ~/.config/ml4w/scripts/cleanup.sh }
function shutdown { systemctl poweroff }
function gcredential { git config credential.helper store }
function lt { eza -a --tree --level=1 --icons=always }
function which ($command) {
  return (Get-Command -Name $command -ErrorAction SilentlyContinue).Path
}
function Edit-Profileconfig {
  nvim (Get-Item $PROFILE | Select-Object -expand Directory | Join-Path -ChildPath powershell.config.json)
}
function Edit-Profile {
  nvim $PROFILE
}

function Show-fzfPreview {
  [CmdletBinding()]
  [Alias('fz')]
  param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$Path = "."
  )

  end {
    return find -path $Path -type d | grep -v \.git | fzf --multi --height=80% --border=sharp `
      --preview='tree -C {}' --preview-window='45%,border-sharp' `
      --prompt='Dirs > ' `
      --bind='del:execute(rm -ri {+})' `
      --bind='ctrl-p:toggle-preview' `
      --bind='ctrl-d:change-prompt(Dirs > )' `
      --bind='ctrl-d:+reload(find -type d | grep -v \.git)' `
      --bind='ctrl-d:+change-preview(tree -C {})' `
      --bind='ctrl-d:+refresh-preview' `
      --bind='ctrl-f:change-prompt(Files > )' `
      --bind='ctrl-f:+reload(find -type f | grep -v \.git)' `
      --bind='ctrl-f:+change-preview(cat {})' `
      --bind='ctrl-f:+refresh-preview' `
      --bind='ctrl-a:select-all' `
      --bind='ctrl-x:deselect-all' `
      --header '
    CTRL-F to display files | CTRL-D to display directories
    CTRL-A to select all | CTRL-x to deselect all
    ENTER to edit | DEL to delete
    CTRL-P to toggle preview
    '
  }
}

function Invoke-Recorder {
  [CmdletBinding(ConfirmImpact = "Low")][Alias("record")]
  param (
    [string]$MediaDir = "$HOME/Pictures"
  )
  Begin {
    function Resolve-Requirements {
      param (
        [string[]]$commands,
        [switch]$InstallMissing
      )
      $commands | ForEach-Object {
        if (!(Get-Command -Name $_ -ErrorAction SilentlyContinue)) {
          if ($InstallMissing) {
            Write-Host "[yay] Installing $_"
            yay -S $_
          } else {
            Write-Warning "Command '$_' not found. Please ensure it's installed and in your PATH."
          }
        }
      }
      # Test WfRecorder
      if (Get-Process -Name "wf-recorder" -ErrorAction SilentlyContinue) {
        Stop-Process -Name "wf-recorder" -Force
        $recordingPath = Get-Content -Path "/tmp/recording.txt"
        & notify-send "Stopping all instances of wf-recorder" "$recordingPath"
        # & wl-copy (Get-Content -Path $recordingPath)
        exit
      }
    }
  }
  Process {
    Resolve-Requirements @(
      "wf-recorder",
      "grim",
      "slurp",
      "montage",
      "notify-send",
      "wl-copy"
    ) -InstallMissing
    $selection = "record screen" # by default
    $selection = @(
      "record screen",
      "screenshot selection",
      "screenshot DP-1",
      "screenshot DP-2"
    ) | fuzzel -d -p "📷 " -w 25 -l 6 --background-color=f0f60000 --text-color=657b83ff --prompt-color=586e75ff --input-color=657b83ff

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss";
    $imgoutput = [IO.Path]::Combine($MediaDir, "Screenshots"); $vidoutput = [IO.Path]::Combine($MediaDir, "Recordings"); ($imgoutput, $vidoutput).ForEach({ New-Directory $_ })

    $imagePath = [IO.Path]::Combine($imgoutput, "$timestamp.png");
    $videoPath = [IO.Path]::Combine($vidoutput, "$timestamp.mp4");

    switch ($selection) {
      "record screen" {
        Set-Content -Path "/tmp/recording.txt" -Value $videoPath
        wf-recorder -a -f "$videoPath"
        & notify-send "record started to `"$videoPath`" use ctrl+c to stop"
      }
      "screenshot selection" {
        & grim -g (slurp) $imagePath
        # & wl-copy (Get-Content -Path $imagePath)
        & notify-send "Screenshot Taken" $imagePath
      }
      "screenshot DP-1" {
        & grim -c -o DP-1 $imagePath
        # & wl-copy (Get-Content -Path $imagePath)
        & notify-send "Screenshot Taken" $imagePath
      }
      "screenshot DP-2" {
        & grim -c -o DP-2 $imagePath
        # & wl-copy (Get-Content -Path $imagePath)
        & notify-send "Screenshot Taken" $imagePath
      }
      "screenshot both screens" {
        $dp1Path = $imagePath -replace '\.png$', '-DP-1.png'
        $dp2Path = $imagePath -replace '\.png$', '-DP-2.png'

        & grim -c -o DP-1 $dp1Path
        & grim -c -o DP-2 $dp2Path
        & montage $dp1Path $dp2Path -tile 2x1 -geometry +0+0 $imagePath
        # & wl-copy (Get-Content -Path $imagePath)
        Remove-Item $dp1Path, $dp2Path
        & notify-send "Screenshot Taken" $imagePath
      }
      default {
        Write-Host "No valid selection made." -ForegroundColor Yellow
      }
    }
    Clear-Host
  }
}

if ($_cfg.UseZoxide) {
  [ScriptBlock]::Create([string]::join("`n", @(& zoxide init powershell))).Invoke()
}

if ($_cfg.UseOmp) {
  [IO.File]::Exists($omp_config) ? [ScriptBlock]::Create([string]::join("`n", @(& oh-my-posh init powershell --config="$omp_config" --print))).Invoke() : (Write-Warning "Cannot find $omp_config!")
}
Remove-Variable _cfg -Scope Local
$VerbosePreference = "Continue"

if ([IO.Path]::Exists('/home/alain/.pyenv/bin')) { cliHelper.env\Set-Env -Name PATH -Scope 'Machine' -Value ('{0}{1}{2}' -f $env:PATH, [IO.Path]::PathSeparator, '/home/alain/.pyenv/bin') }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }

if (![bool](Get-Command pipenv -ea Ignore)) { Set-Alias pipenv pipEnv\Invoke-PipEnv -Scope Global }
