# Script to use the app icon and generate all required sizes
# Works with both SVG and PNG source files

$ErrorActionPreference = "Stop"

# Ensure we're in the correct directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Try to find the icon source file (priority: logo.png, then SVG, then other PNG)
$logoPath = "logo.png"
$svgPath = "assets/images/app_icon_template.svg"
$pngPath = "assets/images/app_icon.png"

$sourceFile = $null
$isSvg = $false

if (Test-Path $logoPath) {
    $sourceFile = $logoPath
    $isSvg = $false
    Write-Host "Found logo: $logoPath" -ForegroundColor Green
} elseif (Test-Path $svgPath) {
    $sourceFile = $svgPath
    $isSvg = $true
    Write-Host "Found SVG icon: $svgPath" -ForegroundColor Green
} elseif (Test-Path $pngPath) {
    $sourceFile = $pngPath
    $isSvg = $false
    Write-Host "Found PNG icon: $pngPath" -ForegroundColor Green
} else {
    Write-Host "ERROR: No icon file found!" -ForegroundColor Red
    Write-Host "Please place your icon as:" -ForegroundColor Yellow
    Write-Host "  - logo.png (PNG, recommended)" -ForegroundColor White
    Write-Host "  - assets/images/app_icon_template.svg (SVG)" -ForegroundColor White
    Write-Host "  - OR assets/images/app_icon.png (PNG)" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "Generating app icons..." -ForegroundColor Yellow
Write-Host ""

# Check for ImageMagick
$magickAvailable = $false
$magickPath = $null

# Try to find magick command
try {
    $null = Get-Command magick -ErrorAction Stop
    $magickPath = "magick"
    $magickAvailable = $true
} catch {
    # Try full path
    $fullPath = "C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe"
    if (Test-Path $fullPath) {
        $magickPath = $fullPath
        $magickAvailable = $true
    } else {
        Write-Host "ImageMagick not found. Checking for Python..." -ForegroundColor Yellow
    }
}

if ($magickAvailable) {
    Write-Host "Using ImageMagick..." -ForegroundColor Green
    Write-Host ""
    
    # Android icons
    Write-Host "Generating Android icons..." -ForegroundColor Cyan
    $androidSizes = @{
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" = 48
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" = 72
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" = 96
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" = 144
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" = 192
    }
    
    foreach ($icon in $androidSizes.GetEnumerator()) {
        $outputPath = $icon.Key
        $size = $icon.Value
        
        $dir = Split-Path -Parent $outputPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        if ($isSvg) {
            & $magickPath -background none -density 300 $sourceFile -resize "${size}x${size}" $outputPath
        } else {
            & $magickPath $sourceFile -resize "${size}x${size}" -background none $outputPath
        }
        Write-Host "  ✓ $outputPath ($size x $size)" -ForegroundColor Gray
    }
    
    # Web icons
    Write-Host ""
    Write-Host "Generating Web icons..." -ForegroundColor Cyan
    $webSizes = @{
        "web/icons/Icon-192.png" = 192
        "web/icons/Icon-512.png" = 512
        "web/icons/Icon-maskable-192.png" = 192
        "web/icons/Icon-maskable-512.png" = 512
    }
    
    foreach ($icon in $webSizes.GetEnumerator()) {
        $outputPath = $icon.Key
        $size = $icon.Value
        
        $dir = Split-Path -Parent $outputPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        if ($isSvg) {
            & $magickPath -background none -density 300 $sourceFile -resize "${size}x${size}" $outputPath
        } else {
            & $magickPath $sourceFile -resize "${size}x${size}" -background none $outputPath
        }
        Write-Host "  ✓ $outputPath ($size x $size)" -ForegroundColor Gray
    }
    
    # Web favicon
    Write-Host ""
    Write-Host "Generating favicon..." -ForegroundColor Cyan
    if ($isSvg) {
        & $magickPath -background none -density 300 $sourceFile -resize "32x32" "web/favicon.png"
    } else {
        & $magickPath $sourceFile -resize "32x32" -background none "web/favicon.png"
    }
    Write-Host "  ✓ web/favicon.png (32 x 32)" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "✓ All icons generated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Rebuild: flutter clean && flutter build apk" -ForegroundColor White
    Write-Host "  2. Check icon on device" -ForegroundColor White
    
} else {
    Write-Host ""
    Write-Host "ImageMagick not available. Please use one of these options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1: Install ImageMagick" -ForegroundColor Cyan
    Write-Host "  choco install imagemagick" -ForegroundColor White
    Write-Host "  Then run: .\use_icon.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Option 2: Use online converter" -ForegroundColor Cyan
    Write-Host "  1. Open $sourceFile" -ForegroundColor White
    Write-Host "  2. Go to https://convertio.co/svg-png/ or https://cloudconvert.com" -ForegroundColor White
    Write-Host "  3. Export in these sizes and save to:" -ForegroundColor White
    Write-Host ""
    Write-Host "Android (save to android/app/src/main/res/):" -ForegroundColor Yellow
    Write-Host "  - 48x48 → mipmap-mdpi/ic_launcher.png" -ForegroundColor White
    Write-Host "  - 72x72 → mipmap-hdpi/ic_launcher.png" -ForegroundColor White
    Write-Host "  - 96x96 → mipmap-xhdpi/ic_launcher.png" -ForegroundColor White
    Write-Host "  - 144x144 → mipmap-xxhdpi/ic_launcher.png" -ForegroundColor White
    Write-Host "  - 192x192 → mipmap-xxxhdpi/ic_launcher.png" -ForegroundColor White
    Write-Host ""
    Write-Host "Web (save to web/icons/):" -ForegroundColor Yellow
    Write-Host "  - 192x192 → Icon-192.png" -ForegroundColor White
    Write-Host "  - 512x512 → Icon-512.png" -ForegroundColor White
    Write-Host "  - 192x192 → Icon-maskable-192.png" -ForegroundColor White
    Write-Host "  - 512x512 → Icon-maskable-512.png" -ForegroundColor White
    Write-Host "  - 32x32 → web/favicon.png" -ForegroundColor White
    exit 1
}

