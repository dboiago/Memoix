# PowerShell script to rename all external_storage references to personal_storage
# Run from project root: .\scripts\rename_external_to_personal.ps1

$ErrorActionPreference = "Stop"

Write-Host "Starting rename from external_storage to personal_storage..." -ForegroundColor Green

# Define replacements
$replacements = @{
    # Provider name
    'externalStorageServiceProvider' = 'personalStorageServiceProvider'
    'ExternalStorageService' = 'PersonalStorageService'
    'ExternalStorageProvider' = 'PersonalStorageProvider'
    'ExternalStorageScreen' = 'PersonalStorageScreen'
    'toExternalStorage' = 'toPersonalStorage'
    
    # Comments
    'Notify external storage service' = 'Notify personal storage service'
    'external storage sync on launch' = 'personal storage sync on launch'
    
    # File imports (only update the path, filenames already renamed)
    "import '../features/external_storage/" = "import '../features/personal_storage/"
    "import '../../external_storage/" = "import '../../personal_storage/"
    "import 'external_storage_provider.dart'" = "import 'personal_storage_provider.dart'"
    "import 'external_storage_service.dart'" = "import 'personal_storage_service.dart'"
    "import 'external_storage_screen.dart'" = "import 'personal_storage_screen.dart'"
    
    # SharedPreferences keys (update for consistency since user is only tester)
    "'external_storage_last_sync'" = "'personal_storage_last_sync'"
    "'external_storage_sync_mode'" = "'personal_storage_sync_mode'"
    "'external_storage_provider_id'" = "'personal_storage_provider_id'"
    "'external_storage_path'" = "'personal_storage_path'"
    
    # Debug messages
    'ExternalStorageService:' = 'PersonalStorageService:'
    'ExternalStorageProvider interface' = 'PersonalStorageProvider interface'
}

# Get all Dart files
$dartFiles = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse -File

$fileCount = 0
$replaceCount = 0

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    foreach ($old in $replacements.Keys) {
        $new = $replacements[$old]
        if ($content -match [regex]::Escape($old)) {
            $content = $content -replace [regex]::Escape($old), $new
            $replaceCount++
        }
    }
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $fileCount++
        Write-Host "Updated: $($file.FullName.Replace((Get-Location).Path + '\', ''))" -ForegroundColor Cyan
    }
}

Write-Host "`nComplete!" -ForegroundColor Green
Write-Host "Files updated: $fileCount" -ForegroundColor Yellow
Write-Host "Replacements made: $replaceCount" -ForegroundColor Yellow
Write-Host "`nDon't forget to:" -ForegroundColor Magenta
Write-Host "1. Run: flutter pub get" -ForegroundColor White
Write-Host "2. Run: flutter pub run build_runner build --delete-conflicting-outputs" -ForegroundColor White
Write-Host "3. Test the app thoroughly" -ForegroundColor White
