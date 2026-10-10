@echo off
setlocal
title Instalador de Cursores Animados
echo.
echo  ==========================================
echo    Instalador de Cursores Animados
echo  ==========================================
echo.
echo   [1] Instalar os cursores
echo   [2] Restaurar os cursores padrao do Windows
echo.
choice /c 12 /n /m "  Escolha uma opcao: "
if errorlevel 2 (set "MODE=restore") else (set "MODE=install")
set "SRC=%~dp0"
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = Get-Content -Raw -Encoding UTF8 -LiteralPath '%~f0'; Invoke-Expression ([regex]::Split($t, '(?m)^#PS-START\r?$')[1])"
echo.
pause
exit /b

#PS-START
$ErrorActionPreference = 'Stop'
$mode       = $env:MODE
$src        = $env:SRC.TrimEnd('\')
$dest       = Join-Path $env:LOCALAPPDATA 'CursoresAnimados'
$schemeName = 'Cursor Animado'
$regPath    = 'HKCU:\Control Panel\Cursors'

# papel no Windows -> nome do arquivo .ani do pacote
$map = [ordered]@{
    Arrow       = 'normal'
    Help        = 'help'
    AppStarting = 'working'
    Wait        = 'busy'
    Crosshair   = 'precision'
    IBeam       = 'text'
    NWPen       = 'handwriting'
    No          = 'unavailable'
    SizeNS      = 'vertical'
    SizeWE      = 'horizontal'
    SizeNWSE    = 'diagonal1'
    SizeNESW    = 'diagonal2'
    SizeAll     = 'move'
    UpArrow     = 'alternate'
    Hand        = 'link'
    Pin         = 'location'
    Person      = 'person'
}

Add-Type -Namespace Win32 -Name Cur -MemberDefinition '[DllImport("user32.dll", SetLastError=true)] public static extern bool SystemParametersInfo(uint a, uint b, IntPtr c, uint d);'
function Update-Cursors { [void][Win32.Cur]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 3) }

try {
    if ($mode -eq 'install') {

        $files = @(Get-ChildItem -LiteralPath $src -Filter *.ani)
        if ($files.Count -eq 0) { throw "Nenhum arquivo .ani encontrado em: $src (deixe este .bat na mesma pasta dos cursores)" }

        Write-Host "Copiando $($files.Count) cursores para $dest ..."
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        $files | Copy-Item -Destination $dest -Force

        foreach ($k in $map.Keys) {
            $f = Join-Path $dest ($map[$k] + '.ani')
            if (Test-Path -LiteralPath $f) {
                Set-ItemProperty -Path $regPath -Name $k -Value $f -Type ExpandString
                Write-Host ("  OK     {0,-12} <- {1}.ani" -f $k, $map[$k])
            } else {
                Write-Host ("  FALTA  {0}.ani (mantido o cursor atual de {1})" -f $map[$k], $k)
            }
        }

        # registra o esquema para aparecer em Painel de Controle > Mouse > Ponteiros
        $cur    = Get-ItemProperty -Path $regPath
        $scheme = ($map.Keys | ForEach-Object { $cur.$_ }) -join ','
        $schPath = "$regPath\Schemes"
        if (-not (Test-Path $schPath)) { New-Item -Path $schPath -Force | Out-Null }
        New-ItemProperty -Path $schPath -Name $schemeName -Value $scheme -PropertyType ExpandString -Force | Out-Null
        Set-ItemProperty -Path $regPath -Name '(default)' -Value $schemeName
        Set-ItemProperty -Path $regPath -Name 'Scheme Source' -Value 1 -Type DWord

        Update-Cursors
        Write-Host ""
        Write-Host "Pronto! Cursores instalados e aplicados."
        Write-Host "Esquema salvo como '$schemeName' (Configuracoes > Mouse > Ponteiros)."
    }
    else {
        $defaults = [ordered]@{
            Arrow='aero_arrow.cur'; Help='aero_helpsel.cur'; AppStarting='aero_working.ani'
            Wait='aero_busy.ani'; Crosshair=''; IBeam=''; NWPen='aero_pen.cur'
            No='aero_unavail.cur'; SizeNS='aero_ns.cur'; SizeWE='aero_ew.cur'
            SizeNWSE='aero_nwse.cur'; SizeNESW='aero_nesw.cur'; SizeAll='aero_move.cur'
            UpArrow='aero_up.cur'; Hand='aero_link.cur'; Pin='aero_pin.cur'; Person='aero_person.cur'
        }
        foreach ($k in $defaults.Keys) {
            $v = $defaults[$k]
            if ($v) { $v = '%SystemRoot%\cursors\' + $v }
            Set-ItemProperty -Path $regPath -Name $k -Value $v -Type ExpandString
        }
        Set-ItemProperty -Path $regPath -Name '(default)' -Value 'Windows Default'
        Set-ItemProperty -Path $regPath -Name 'Scheme Source' -Value 2 -Type DWord
        Remove-ItemProperty -Path "$regPath\Schemes" -Name $schemeName -ErrorAction SilentlyContinue

        Update-Cursors
        Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cursores padrao do Windows restaurados."
    }
}
catch {
    Write-Host ""
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
}
