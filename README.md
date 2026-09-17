# Scripts necesarios para integrar PAU → SSIPE

Carpeta depurada conforme a los manuales internos PAU:

- `http://10.0.0.34:9102/integration`
- `http://10.0.0.34:9102/catalogo-api/pau`

PAU autentica mediante `Auth/Integration` y `Auth/GetUsuarioLoginPorIdSis`. Estos scripts no reemplazan ese contrato: implementan en DBSSIPE2 la homologación de sus usuarios, perfiles, menús y permisos al modelo histórico de SSIPE, incluido el módulo Asignar Proyecto.

Ambientes autorizados: DBSSIPE2 en `PVDDEV-BD07\ARTEMISA36`, DBSSO de desarrollo para la línea base de solo lectura, y `PVDPAU_PROD` en `10.4.0.20\artemisa20` (base DESA del PAU; `PVDSMV` es el SMV y no aplica). No contienen contraseñas y no deben ejecutarse en QA ni producción sin una aprobación específica.

## Orden de ejecución

| Paso | Archivo | Base | Propósito |
|---:|---|---|---|
| 0 | `00_diagnostico_DBSSIPE2.sql` | DBSSIPE2 | Inventario y verificación inicial, solo lectura |
| 1 | `08_linea_base_SSO_solo_lectura.sql` | DBSSO | Catálogo de perfiles/usuarios que deben homologarse |
| 2 | `01_tablas_homologacion_DBSSIPE2.sql` | DBSSIPE2 | Tablas de usuario, perfil, menú y operación PAU |
| 3 | `05_contrato_menu_ssipe_DBSSIPE2.sql` | DBSSIPE2 | Procedimiento vigente para construir la sesión SSIPE |
| 4 | `03_pruebas_homologacion_DBSSIPE2.sql` | DBSSIPE2 | Pruebas negativas y de permisos con rollback |
| 5 | `07_prueba_contrato_menu_corregida_DBSSIPE2.sql` | DBSSIPE2 | Prueba del formato de menú esperado por el frontend |
| 6 | `11_directorio_usuarios_PAU_DBSSIPE2.sql` | DBSSIPE2 | Directorio local alimentado al autenticar en PAU |
| 7 | `12_pruebas_directorio_PAU_DBSSIPE2.sql` | DBSSIPE2 | Prueba transaccional del directorio |
| 8a | `16_export_usuarios_perfiles_SSO_para_PAU.sql` | DBSSO | Export solo lectura: perfiles, usuarios, menú y claims SSIPE (evidencia `integracion/evidencias/16_export_SSO_ssipe.json`) |
| 8b | `14_inventario_PAU_PVDPAU_PROD.sql` | PVDPAU_PROD (PAU DESA, Artemisa20) | Solo lectura: id de SSIPE en PAU, usuario 42910203, perfiles existentes, tablas reales |
| 8c | `15_alta_perfil_coordinador_obra_PAU_PVDPAU_PROD.sql` | PVDPAU_PROD | Crea perfil COORDINADOR DE OBRA + grupo + asignación del usuario de prueba vía SP del PAU (o hacerlo desde el front PAU) |
| 8d | `17_homologacion_usuario_prueba_P0025_DBSSIPE2.sql` | DBSSIPE2 | Carga de homologación del usuario de prueba con P0025 (generado desde el export SSO; completar ids PAU) |
| 8e | `18_alta_masiva_perfiles_SSIPE_en_PAU_PVDPAU_PROD.sql` | PVDPAU_PROD | Alta masiva de perfiles SSIPE en PAU (perfil + rol + módulos + grupo). Marcar `Activar=1` solo en los aprobados; devuelve los `PerfilPauId` |
| 8f | `18b_asignaciones_usuarios_PAU_PVDPAU_PROD.sql` (en `integracion/evidencias/privado/`, **no en git**: contiene DNIs) | PVDPAU_PROD | Asigna usuarios reales a los perfiles creados, cruzando por documento; reporta los que no existen en PAU |
| 8g | `19_homologacion_masiva_perfiles_DBSSIPE2.sql` | DBSSIPE2 | PauPerfil + PauMenu + PauOperacion para todos los perfiles (39 menús, 710 claims). Completar `@map` con los ids del 18 |
| 9 | `13_precheck_cutover_asignar_proyecto_DBSSIPE2.sql` | DBSSIPE2 | Decide si existe cobertura suficiente para cortar SSO |
| 10 | `13_cutover_asignar_proyecto_PAU_DBSSIPE2.sql` | DBSSIPE2 | Sustituye las vistas SSO únicamente si pasan las guardas |
| R | `13_rollback_asignar_proyecto_SSO_DBSSIPE2.sql` | DBSSIPE2 | Restaura temporalmente las vistas SSO |

`Ejecutar-Desarrollo.ps1` acepta únicamente scripts DBSSIPE2 de esta lista, fija servidor/base, separa lotes `GO` y genera evidencia JSON con SHA-256. En una copia independiente toma la conexión desde `SSIPE_DBSSIPE2_CONNECTION`; dentro del workspace SSIPE también puede leer el `appsettings.json` local. Nunca imprime la cadena. La línea base DBSSO se ejecuta por separado y es estrictamente de lectura.

## Estado actual

La infraestructura hasta el paso 7 fue aplicada y probada en DBSSIPE2. El último precheck devolvió `ListoParaCorte=0` porque aún no existen homologaciones ni identidades PAU reales. Por ese motivo el corte no fue ejecutado y las asignaciones existentes permanecen intactas.

## Archivos retirados

- `02` y `04`: versiones reemplazadas del resolvedor.
- `06`: prueba con error de sintaxis, reemplazada por `07`.
- `09`, `09b` y `09c`: verificaciones intermedias o redundantes.
- `10_PAU_ticket_integracion_PVDSMV.sql`: prototipo v2 ajeno al contrato oficial PAU.

No agregar secretos, tokens, datos personales ni copias de `appsettings.json` a este repositorio.
