
# Remove all files in the directory
Remove-Item -Path "~/.config/ml4w/cache/wallpaper-generated/*" -Recurse -Force

# Output a message to the console
Write-Host ":: Wallpaper cache cleared" -f Green
&notify-send "Wallpaper cache cleared"


# Initialize counters
$i1 = 1
$i2 = 1

# Rename all files in the directory, excluding the script and README file
Get-ChildItem -File | Where-Object { $_.Name -notmatch 'rename-wallpapers.ps1|README.md' } | ForEach-Object {
  $newName = "{0:D9}.png" -f $i1
  Rename-Item -Path $_.FullName -NewName $newName
  $i1++
}

# Rename all files in the directory again, excluding the script and README file
Get-ChildItem -File | Sort-Object LastWriteTime | Where-Object { $_.Name -notmatch 'rename-wallpapers.ps1|README.md' } | ForEach-Object {
  $newName = "{0:D2}.png" -f $i2
  Rename-Item -Path $_.FullName -NewName $newName
  $i2++
}

# Create or overwrite README.md
"## wallpapers" | Out-File -FilePath README.md

# Append file names and markdown image links to README.md
Get-ChildItem -File | Where-Object { $_.Name -notmatch 'rename-wallpapers.ps1|README.md' } | ForEach-Object {
  $file = $_.Name
  "$file  " | Out-File -FilePath README.md -Append
  "![$file]($file)" | Out-File -FilePath README.md -Append
}
