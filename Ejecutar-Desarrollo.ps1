[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('00_diagnostico_DBSSIPE2.sql','01_tablas_homologacion_DBSSIPE2.sql','03_pruebas_homologacion_DBSSIPE2.sql','05_contrato_menu_ssipe_DBSSIPE2.sql','07_prueba_contrato_menu_corregida_DBSSIPE2.sql','11_directorio_usuarios_PAU_DBSSIPE2.sql','12_pruebas_directorio_PAU_DBSSIPE2.sql','13_precheck_cutover_asignar_proyecto_DBSSIPE2.sql','13_cutover_asignar_proyecto_PAU_DBSSIPE2.sql','13_rollback_asignar_proyecto_SSO_DBSSIPE2.sql')][string]$Archivo
)
$ErrorActionPreference='Stop'
$workspace=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$connectionValue=[Environment]::GetEnvironmentVariable('SSIPE_DBSSIPE2_CONNECTION')
$localSettings=Join-Path $workspace 'BACK/ssipe_back/pvd.ssipe/appsettings.json'
if([string]::IsNullOrWhiteSpace($connectionValue) -and (Test-Path -LiteralPath $localSettings)){
 $settings=Get-Content -LiteralPath $localSettings -Raw|ConvertFrom-Json
 $connectionValue=[string]$settings.ConnectionStrings.cnx_ssipe
}
if([string]::IsNullOrWhiteSpace($connectionValue)){
 throw 'Defina SSIPE_DBSSIPE2_CONNECTION. En el workspace SSIPE también se admite su appsettings.json local.'
}
$builder=[System.Data.SqlClient.SqlConnectionStringBuilder]::new($connectionValue)
$builder['Data Source']='10.4.0.36,59231';$builder['Initial Catalog']='DBSSIPE2'
$builder['Encrypt']=$false;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=30
$path=Join-Path $PSScriptRoot $Archivo
$batches=@([regex]::Split((Get-Content $path -Raw),'(?im)^\s*GO\s*$')|Where-Object {$_.Trim()})
$connection=[System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$results=[Collections.Generic.List[object]]::new()
try {
 $connection.Open()
 $check=$connection.CreateCommand()
 $check.CommandText="SELECT CASE WHEN DB_NAME()='DBSSIPE2' AND CONVERT(nvarchar(128),SERVERPROPERTY('MachineName'))='PVDDEV-BD07' THEN 1 ELSE 0 END"
 if([int]$check.ExecuteScalar() -ne 1){throw 'La conexión no corresponde a DBSSIPE2 de desarrollo.'}
 foreach($batch in $batches){
  $command=$connection.CreateCommand();$command.CommandTimeout=90;$command.CommandText=$batch
  $adapter=[System.Data.SqlClient.SqlDataAdapter]::new($command)
  $dataset=[System.Data.DataSet]::new();[void]$adapter.Fill($dataset)
  foreach($table in $dataset.Tables){foreach($row in $table.Rows){
   $item=[ordered]@{};foreach($column in $table.Columns){$item[$column.ColumnName]=if($row[$column] -is [DBNull]){$null}else{$row[$column]}}
   $results.Add([pscustomobject]$item)
  }}
  $adapter.Dispose();$command.Dispose()
 }
 $report=[ordered]@{FechaUtc=[DateTime]::UtcNow.ToString('O');Base='DBSSIPE2';Servidor='PVDDEV-BD07\ARTEMISA36';Archivo=$Archivo;SHA256=(Get-FileHash $path -Algorithm SHA256).Hash;Estado='OK';Resultados=$results.ToArray()}
 $evidenceRoot=if(Test-Path -LiteralPath (Join-Path $workspace 'integracion')){Join-Path $workspace 'integracion/evidencias'}else{Join-Path $PSScriptRoot 'evidencias'}
 [IO.Directory]::CreateDirectory($evidenceRoot)|Out-Null
 $output=Join-Path $evidenceRoot ([IO.Path]::GetFileNameWithoutExtension($Archivo)+'_resultado.json')
 [IO.File]::WriteAllText($output,($report|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
 Write-Output "OK: $Archivo en DBSSIPE2. Evidencia: $output"
 $results|Format-Table -AutoSize
} finally {$connection.Dispose()}
