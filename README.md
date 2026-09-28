# Fase 1 — Scripts de la integración temporal PAU → SSIPE

> Esto es la **Fase 1** de la integración PAU↔SSIPE: un puente **temporal**, implementado enteramente
> por homologación SQL en el esquema `integracion` de DBSSIPE2, sin tocar el código fuente de PAU ni de
> SGA/SSO. Existe una **Fase 2** (modelo de identidad unificado IAM, basado en FICAM) que eventualmente
> reemplazaría este puente — hoy está en análisis, sin código ni cronograma comprometido. Ver
> [`integracion/README.md`](../../integracion/README.md) para el panorama completo de ambas fases, y
> [`integracion/fase1-temporal-pau-ssipe/README.md`](../../integracion/fase1-temporal-pau-ssipe/README.md)
> para la documentación operativa de esta Fase 1 (handoff, casos de prueba, reportes de actividad).

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
| 8a | `16_export_usuarios_perfiles_SSO_para_PAU.sql` | DBSSO | Export solo lectura: perfiles, usuarios, menú y claims SSIPE (evidencia `integracion/fase1-temporal-pau-ssipe/evidencias/16_export_SSO_ssipe.json`) |
| 8b | `14_inventario_PAU_PVDPAU_PROD.sql` | PVDPAU_PROD (PAU DESA, Artemisa20) | Solo lectura: id de SSIPE en PAU, usuario 42910203, perfiles existentes, tablas reales |
| 8c | `15_alta_perfil_coordinador_obra_PAU_PVDPAU_PROD.sql` | PVDPAU_PROD | Crea perfil COORDINADOR DE OBRA + grupo + asignación del usuario de prueba vía SP del PAU (o hacerlo desde el front PAU) |
| 8d | `17_homologacion_usuario_prueba_P0025_DBSSIPE2.sql` | DBSSIPE2 | Carga de homologación del usuario de prueba con P0025 (generado desde el export SSO; completar ids PAU) |
| 8e | `18_alta_masiva_perfiles_SSIPE_en_PAU_PVDPAU_PROD.sql` | PVDPAU_PROD | Alta masiva de perfiles SSIPE en PAU (perfil + rol + módulos + grupo). Marcar `Activar=1` solo en los aprobados; devuelve los `PerfilPauId` |
| 8f | `18b_asignaciones_usuarios_PAU_PVDPAU_PROD.sql` (en `integracion/fase1-temporal-pau-ssipe/evidencias/privado/`, **no en git**: contiene DNIs) | PVDPAU_PROD | Asigna usuarios reales a los perfiles creados, cruzando por documento; reporta los que no existen en PAU |
| 8g | `19_homologacion_masiva_perfiles_DBSSIPE2.sql` | DBSSIPE2 | PauPerfil + PauMenu + PauOperacion para todos los perfiles (39 menús, 710 claims). Completar `@map` con los ids del 18 |
| 9 | `27_sp_sesion_directorio_PAU.sql` | DBSSIPE2 | SPs de sesión y directorio PAU sin el candado `DB_NAME()` en el cuerpo (portables a QA/PROD) |
| 10 | `28_identidad_usuario_y_areas.sql` | DBSSIPE2 | Vista `integracion.vw_UsuarioSsipe` (identidad desde PAU) + `integracion.paListarArea` (reemplaza el bloque 1 de `DESPLIEGUE_2_DBSSO.sql`) |
| 11 | `30_claims_ejecucion_cva_PAU.sql` | DBSSIPE2 | Los 11 claims de Ejecución CVA en `PauOperacion` (reemplaza el bloque 2 de `DESPLIEGUE_2_DBSSO.sql`) |
| 12 | `29_corte_identidad_sso_asignar_proyecto.sql` | DBSSIPE2 | Corte: Asignar Proyecto y filtros de Seguimiento leen identidad solo de PAU |
| R | `29R_rollback_corte_identidad_sso.sql` | DBSSIPE2 | Vuelve a las vistas SSO (junto con `PauIntegration:Enabled=false` en el back) |

Los `13_precheck/cutover/rollback_asignar_proyecto` quedan **reemplazados por el 29/29R**: solo cubrían 1 de los 4 SPs que leían identidad del SSO y dependían de un directorio que se llenaba únicamente al iniciar sesión.

**Aplicado en DBSSIPE2 el 25/09/2026:** 27, 28, 25 v2 y 29 (el 30 no tuvo nada que insertar). El paquete para QA/PROD, validado contra DBSSIPE3, está en [`PASE_QA_PROD/`](PASE_QA_PROD/README.md).

`Ejecutar-Desarrollo.ps1` acepta únicamente scripts DBSSIPE2 de esta lista, fija servidor/base, separa lotes `GO` y genera evidencia JSON con SHA-256. En una copia independiente toma la conexión desde `SSIPE_DBSSIPE2_CONNECTION`; dentro del workspace SSIPE también puede leer el `appsettings.json` local. Nunca imprime la cadena. La línea base DBSSO se ejecuta por separado y es estrictamente de lectura.

## Estado actual (actualizado sep-2026)

La infraestructura hasta el paso 7 fue aplicada y probada en DBSSIPE2. Los pasos 8a-8g ya se ejecutaron
para el equipo que migró desde el SSO clásico (4 usuarios reales homologados: alias U1-U4, ver
`integracion/fase1-temporal-pau-ssipe/evidencias/privado/usuarios_prueba_alias.md`), con perfiles P0001,
P0023, P0024 y P0025 activos. Verificado de punta a punta (`paResolverSesionPau` con `estado=1` y menú
correcto) **solo para el usuario de prueba `42910203`** — los demás (U2-U4) están homologados en
DBSSIPE2 y asignados en PAU pero sin una verificación end-to-end documentada todavía.

**Decisión 25/09/2026:** desde el pase a producción SSIPE entra **solo por PAU**. El back (`dev_pau`) rechaza el token SSO y toma `IdUsuario`/auditoría de la sesión, y en DBSSIPE2 ya se aplicó el corte de identidad (script 29). El SSO sigue vivo solo como catálogo de áreas y como fuente del `IdUsuario` histórico al homologar.

## Estandar reutilizable para altas de usuario (a partir de sep-2026)

Los pasos 8a-8g de arriba fueron el trabajo puntual para poner en marcha la integración (usuarios del
equipo SSO migrados a PAU). Para **cualquier lote nuevo** de usuarios + perfiles que llegue de aquí en
adelante, usar en su lugar estos dos archivos (no crear un script nuevo por lote):

| Fase | Archivo | Base | Qué hace |
|---|---|---|---|
| 1 | `24_ALTA_ESTANDAR_asignar_perfil_PAU.sql` | PVDPAU_PROD (o su equivalente por ambiente) | Único archivo a editar por lote: completar la tabla `@asig` con Documento/Nombre/CodigoSSO. Asigna el perfil en PAU de forma idempotente (`@confirmar=0` simula). |
| 2 | `25_SP_paHomologarUsuariosPau_DBSSIPE2.sql` | DBSSIPE2 (o su equivalente por ambiente) | Crea el procedimiento `integracion.paHomologarUsuariosPau` (una sola vez por ambiente). Se invoca por lote con el JSON que devuelve la última consulta del 24. Reutiliza el `IdUsuario` si el documento ya es un usuario SSIPE conocido en el SSO o si ya estaba homologado; si es genuinamente nuevo le asigna uno nunca antes emitido. **v2:** también registra al usuario en `integracion.PauDirectorio`, así aparece en Asignar Proyecto antes de su primer ingreso. |

**Desde un Excel (DESA o PROD):** `herramientas/generar_alta_usuarios.py` lee un Excel con las columnas *APELLIDOS Y NOMBRES | DNI | PERFIL* e ignora las demás, incluidas claves u observaciones. Acepta el perfil por nombre ("Administrador de Contrato", "Coordinador de obra"…) o por código Pxxxx. Genera los dos scripts del lote: `_1_PAU.sql` (el 24 con `@asig` cargado) y `_2_SSIPE.sql` (llamada al 25, donde se pega el `JsonParaScript25`). Los scripts generados contienen DNIs: guardarlos en `integracion/fase1-temporal-pau-ssipe/docs/USUARIOS/lotes/`, que está fuera de git.

```
python herramientas/generar_alta_usuarios.py usuarios.xlsx --salida <carpeta lotes> --revisado-por <DNI>
       --ambiente PROD --pau-db <base PAU PROD> --ssipe-db <base SSIPE PROD> --sistema-id <id SSIPE en PAU PROD> --id-area-defecto <IdArea>
```

Los usuarios que no existen en PAU salen como `USUARIO NO EXISTE EN PAU`: se registran por el portal PAU y se vuelve a correr el mismo lote, que es idempotente.

Este estándar no reemplaza los pasos 0-7 (infraestructura de tablas/SP, se corren una sola vez) ni el
18/19 (alta de un perfil SSIPE nuevo en PAU, se corre una sola vez por perfil, no por usuario).

## Cambiar a que ambiente redirige el botón de SSIPE en el PAU

`26_apuntar_sistema_ssipe_ambiente_PVDPAU_PROD.sql` (PVDPAU_PROD) cambia únicamente
`I_SISTEMA_SIS.SIS_V_LINKSI` del sistema 2020 entre el front local (`http://localhost:4200/pau/callback`)
y el desplegado, para poder probar el front de SSIPE en `localhost:4200` desde el botón real del PAU.
Es un switch **global y compartido** (afecta a cualquiera que entre a SSIPE desde el PAU de DESA mientras
esté en LOCAL) — volver a `DESPLIEGUE` al terminar de probar. Ver el encabezado del script para el
requisito adicional en el back (`PauIntegration.IntegrationUrl`/`UserApiUrl` deben apuntar al mismo PAU
que emitió el `unique_code`).

## Archivos retirados

- `02` y `04`: versiones reemplazadas del resolvedor.
- `06`: prueba con error de sintaxis, reemplazada por `07`.
- `09`, `09b` y `09c`: verificaciones intermedias o redundantes.
- `10_PAU_ticket_integracion_PVDSMV.sql`: prototipo v2 ajeno al contrato oficial PAU.

No agregar secretos, tokens, datos personales ni copias de `appsettings.json` a este repositorio.
