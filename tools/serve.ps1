# Tiny local web server for Creazy Shootan! (no install needed). Close the window to stop.
param([int]$Port = 8060)
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\play'))
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try { $listener.Start() } catch { Write-Host "Port $Port is busy. Close the other game window and try again."; pause; exit 1 }
Write-Host "Creazy Shootan! is running at http://localhost:$Port/"
Write-Host "Close this window to stop the game server."
Start-Process "http://localhost:$Port/"
$mime = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript'; '.wasm' = 'application/wasm'; '.png' = 'image/png' }
while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($rel -eq '') { $rel = 'index.html' }
    $file = [IO.Path]::GetFullPath((Join-Path $Root $rel))
    if ($file.StartsWith($Root) -and (Test-Path $file -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($file)
      $ext = [IO.Path]::GetExtension($file).ToLower()
      if ($mime.ContainsKey($ext)) { $ctx.Response.ContentType = $mime[$ext] } else { $ctx.Response.ContentType = 'application/octet-stream' }
      $ctx.Response.Headers.Add('Cache-Control', 'no-cache')
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $ctx.Response.StatusCode = 404
    }
    $ctx.Response.Close()
  } catch { }
}
