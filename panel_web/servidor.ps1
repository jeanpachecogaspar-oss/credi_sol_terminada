# Servidor local mínimo para el panel web de CrediSol (no necesita instalar nada).
# Sirve esta carpeta en http://localhost:5500 . Ciérralo con Ctrl+C o cerrando la ventana.
$ErrorActionPreference = 'Stop'
$puerto = 5500
$raiz = $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$puerto/")
$listener.Start()
Write-Host "Panel CrediSol en http://localhost:$puerto  (Ctrl+C para cerrar)" -ForegroundColor Cyan
Start-Process "http://localhost:$puerto/"

$tipos = @{
  '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.json' = 'application/json'
}
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $ruta = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($ruta)) { $ruta = 'index.html' }
    $archivo = [System.IO.Path]::GetFullPath((Join-Path $raiz $ruta))
    $resp = $ctx.Response
    if ($archivo.StartsWith($raiz) -and (Test-Path $archivo -PathType Leaf)) {
      $bytes = [System.IO.File]::ReadAllBytes($archivo)
      $ext = [System.IO.Path]::GetExtension($archivo).ToLower()
      $resp.ContentType = if ($tipos.ContainsKey($ext)) { $tipos[$ext] } else { 'application/octet-stream' }
      $resp.ContentLength64 = $bytes.Length
      $resp.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $resp.StatusCode = 404
    }
    $resp.Close()
  }
} finally {
  $listener.Stop()
}
