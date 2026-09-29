"""
Arma los scripts consolidados del pase PAU -> SSIPE para la base SSIPE del ambiente, a partir de los
scripts fuente de esta carpeta (no se editan a mano: si cambia un fuente, volver a correr esto):

  PASE_QA_PROD/integracion_pau_ssipe_1_estructura.sql
      P01 + 27 + 28 + 25. Esquema integracion, SPs de sesion/directorio, vista de identidad,
      catalogo de areas y SP de homologacion de usuarios. No necesita datos del PAU.
      Es prerrequisito de DESPLIEGUE_1_DBSSIPE.sql. No cambia el comportamiento del back anterior.

  PASE_QA_PROD/integracion_pau_ssipe_2_perfiles_y_corte.sql
      P02 + 30 + 29. Homologa perfiles/menus/claims con los ids del PAU del ambiente y hace el
      corte de identidad (Asignar Proyecto y filtros leen PAU).

  PASE_QA_PROD/integracion_pau_ssipe_R_rollback_corte.sql
      29R. Solo si el pase falla y hay que volver al SSO.

Cada consolidado se abre y ejecuta tal cual en la ventana de consultas del gestor (SSMS u otro),
sin modo SQLCMD:
  - Los parametros van en la tabla temporal #param, en un unico bloque "EDITAR SOLO AQUI".
  - Todo corre en UNA transaccion: CONFIRMAR 0 simula y revierte; CONFIRMAR 1 aplica.
  - Entre cada bloque (GO) se comprueba que la transaccion siga viva: ante el primer error se
    detiene (SET NOEXEC ON) y al final se revierte todo. Se puede volver a ejecutar en la misma ventana.

Uso:  python armar_integracion_pau_ssipe.py
"""
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "PASE_QA_PROD"

PERFILES_PASE = ["P0001", "P0023", "P0024", "P0025", "P0028", "P0029", "P0045"]
MODULOS = [("2182", "M0001"), ("2183", "M0007"), ("2184", "M0043"), ("2185", "M1051")]


def p_txt(nombre):
    return f"(SELECT Valor FROM #param WHERE Nombre = N'{nombre}')"


def p_int(nombre):
    return f"(SELECT TRY_CONVERT(int, Valor) FROM #param WHERE Nombre = N'{nombre}')"


def leer(rel):
    return (RAIZ / rel).read_text(encoding="ascii").replace("\r\n", "\n")


def reemplazar(texto, viejo, nuevo, veces=1, regex=False):
    n = len(re.findall(viejo, texto)) if regex else texto.count(viejo)
    if n != veces:
        raise SystemExit(f"Se esperaban {veces} coincidencias de {viejo!r} y hay {n}: revisar el fuente.")
    return re.sub(viejo, lambda _: nuevo, texto) if regex else texto.replace(viejo, nuevo)


GUARDA_BLOQUE = """IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'DETENIDO: hubo un error en un bloque anterior. Revise el PRIMER mensaje de error; al final se revierte todo.', 16, 1); SET NOEXEC ON; END
GO
"""


def adaptar(rel, texto=None):
    """Guarda de base por #param, sin SET NOEXEC OFF intermedios, @confirmar interno en 1."""
    t = leer(rel) if texto is None else texto
    t = reemplazar(t, r"IF DB_NAME\(\) <> N'DBSSIPE2?'[^\n]*", "IF DB_NAME() <> " + p_txt("BASE_SSIPE"), regex=True)
    t = re.sub(r"(?m)^SET NOEXEC OFF;[ \t]*\n", "", t)
    t = t.replace("DECLARE @confirmar bit = 0;",
                  "DECLARE @confirmar bit = 1;   -- consolidado: lo decide CONFIRMAR al final del script")
    t = t.replace("PRINT 'COMMIT realizado.';", "PRINT 'Bloque OK (se confirma o revierte al final segun CONFIRMAR).';")
    t = re.sub(r"(?m)^GO[ \t]*\n", "GO\n" + GUARDA_BLOQUE, t.rstrip() + "\nGO\n")
    barra = "-- " + "#" * 76
    return f"{barra}\n-- FUENTE: {rel}\n{barra}\n{t}"


def cabecera(titulo, descripcion, parametros):
    filas = "\n".join(
        f"INSERT #param VALUES (N'{k}', N'{v if v is not None else '<<<COMPLETAR>>>'}');"
        f"{' ' * max(1, 32 - len(k) - len(v if v is not None else '<<<COMPLETAR>>>'))}-- {c}"
        for k, v, c in parametros)
    return f"""/*
================================================================================
 {titulo}
================================================================================
{descripcion}
 COMO SE EJECUTA (ventana de consultas normal del gestor, conectado a la base SSIPE)
   1. Completar SOLO el bloque "EDITAR SOLO AQUI" (debajo).
   2. Ejecutar todo con CONFIRMAR = 0: simula y revierte. Revisar que termine en
      "SIMULACION OK" y sin errores.
   3. Cambiar CONFIRMAR a 1 y ejecutar de nuevo: termina en "COMMIT REALIZADO".
   Si aparece un error, el script se detiene y revierte todo: no queda nada a medias.
 GENERADO por herramientas/armar_integracion_pau_ssipe.py: no editar fuera del bloque.
================================================================================
*/
SET NOEXEC OFF;
IF @@TRANCOUNT > 0 ROLLBACK;
SET NOCOUNT ON;
IF OBJECT_ID(N'tempdb..#param') IS NOT NULL DROP TABLE #param;
CREATE TABLE #param (Nombre sysname PRIMARY KEY, Valor nvarchar(200) NULL);
-- ============================ EDITAR SOLO AQUI ============================
{filas}
-- ==========================================================================
GO
IF DB_NAME() <> {p_txt('BASE_SSIPE')} OR ISNULL({p_txt('CONFIRMAR')}, N'') NOT IN (N'0', N'1')
BEGIN RAISERROR(N'Base conectada distinta de BASE_SSIPE, o CONFIRMAR distinto de 0/1. No se ejecuto nada.', 16, 1); SET NOEXEC ON; END
GO
"""


INICIO_TX = f"""SET XACT_ABORT ON;
BEGIN TRANSACTION;
DECLARE @confirmarTexto nvarchar(10) = {p_txt('CONFIRMAR')};
PRINT CONCAT(N'Inicio en ', @@SERVERNAME, N'.', DB_NAME(), N' | CONFIRMAR=', @confirmarTexto, N' | ', CONVERT(varchar(19), SYSDATETIME(), 120));
GO
"""

FIN_TX = f"""-- ############################################################################
-- CIERRE: confirma o revierte todo lo anterior
-- ############################################################################
{GUARDA_BLOQUE}IF {p_txt('CONFIRMAR')} = N'1' BEGIN COMMIT; PRINT N'COMMIT REALIZADO: cambios aplicados.'; END
ELSE BEGIN ROLLBACK; PRINT N'SIMULACION OK: no se aplico nada. Cambiar CONFIRMAR a 1 y ejecutar de nuevo.'; END
GO
SET NOEXEC OFF;
GO
IF @@TRANCOUNT > 0
BEGIN ROLLBACK; RAISERROR(N'EJECUCION DETENIDA: se revirtio todo. Revise el primer mensaje de error.', 16, 1); END
GO
"""


def escribir(nombre, texto):
    ruta = SALIDA / nombre
    texto.encode("ascii")
    ruta.write_bytes(texto.replace("\r\n", "\n").replace("\n", "\r\n").encode("ascii"))
    print(f"  {ruta.relative_to(RAIZ)}  ({texto.count(chr(10))} lineas)")


BASE = ("BASE_SSIPE", "DBSSIPE", "base SSIPE a la que esta conectado (DESA: DBSSIPE2)")
CONF = ("CONFIRMAR", "0", "0 = simular, 1 = aplicar")


def parte1():
    desc = """ PASE PAU -> SSIPE, PARTE 1 de 2 (estructura). Base SSIPE del ambiente.
   P01 esquema integracion + tablas | 27 SPs de sesion y directorio PAU
   28 vista integracion.vw_UsuarioSsipe + integracion.paListarArea
   25 SP integracion.paHomologarUsuariosPau (v2)
 No necesita ids del PAU ni cambia el comportamiento del back actual.
 Es PRERREQUISITO de DESPLIEGUE_1_DBSSIPE.sql (sus listados leen la vista).
"""
    cuerpo = "".join(adaptar(f) for f in [
        "PASE_QA_PROD/P01_infraestructura_integracion.sql",
        "27_sp_sesion_directorio_PAU.sql",
        "28_identidad_usuario_y_areas.sql",
        "25_SP_paHomologarUsuariosPau_DBSSIPE2.sql",
    ])
    verif = """-- ############################################################################
-- VERIFICACION PARTE 1
-- ############################################################################
SELECT Verificacion = N'Parte 1', Objeto = s.name + N'.' + o.name, o.type_desc
FROM sys.objects o JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = N'integracion' AND o.type IN ('U', 'V', 'P') ORDER BY o.type, o.name;
IF (SELECT COUNT(*) FROM sys.objects o WHERE o.schema_id = SCHEMA_ID(N'integracion')
      AND o.name IN (N'PauUsuario', N'PauPerfil', N'PauMenu', N'PauOperacion', N'PauDirectorio', N'vw_UsuarioSsipe',
                     N'paListarArea', N'paResolverSesionPau', N'paRegistrarDirectorioPau', N'paHomologarUsuariosPau')) <> 10
BEGIN RAISERROR(N'Parte 1 incompleta: faltan objetos de integracion.', 16, 1); SET NOEXEC ON; END
GO
"""
    escribir("integracion_pau_ssipe_1_estructura.sql",
             cabecera("integracion_pau_ssipe_1_estructura.sql", desc, [BASE, CONF]) + INICIO_TX + cuerpo + verif + FIN_TX)


def parte2():
    desc = """ PASE PAU -> SSIPE, PARTE 2 de 2 (perfiles y corte). Base SSIPE del ambiente.
   P02 perfiles/menus/claims SSIPE con los ids del PAU del ambiente
       (P0001, P0023, P0024, P0025, P0028, P0029 y P0045 LECTOR GENERAL = "Seguimiento", solo lectura)
   30  11 claims de Ejecucion CVA
   29  corte de identidad: Asignar Proyecto y filtros de listados leen PAU
 Requiere la parte 1, DESPLIEGUE_1_DBSSIPE.sql y los ids que devuelve el script de perfiles
 en el PAU (P03): salida 'sistema', 'resultado' y 'modulos'.
"""
    params = [BASE, CONF, ("PAU_SISTEMA_ID", None, "P03 'sistema': SistemaId")]
    params += [(f"PAU_PERFIL_{c}", None, f"P03 'resultado': PerfilPauId de {c}") for c in PERFILES_PASE]
    params += [(f"PAU_MODULO_{m}", None, f"P03 'modulos': ModuloPauId de {m}") for _, m in MODULOS]
    faltan = "\n   OR ".join(f"{p_int(k)} IS NULL" for k, _, _ in params[2:])
    valida = f"""IF {faltan}
BEGIN RAISERROR(N'Completar en el bloque EDITAR SOLO AQUI los ids del PAU (salida del script de perfiles P03). No se ejecuto nada.', 16, 1); SET NOEXEC ON; END
GO
"""
    p02 = leer("PASE_QA_PROD/P02_homologacion_perfiles_QA_PROD.sql")
    p02 = reemplazar(p02, "DECLARE @SistemaId int = NULL;", "DECLARE @SistemaId int = " + p_int("PAU_SISTEMA_ID") + ";")
    for c in PERFILES_PASE:
        p02 = reemplazar(p02, f"('{c}', NULL,", f"('{c}', {p_int('PAU_PERFIL_' + c)},")
    for desa, m in MODULOS:
        p02 = reemplazar(p02, f"(N'{desa}', '{m}', NULL)", f"(N'{desa}', '{m}', {p_txt('PAU_MODULO_' + m)})")
    cuerpo = (adaptar("PASE_QA_PROD/P02_homologacion_perfiles_QA_PROD.sql", p02)
              + adaptar("30_claims_ejecucion_cva_PAU.sql")
              + adaptar("29_corte_identidad_sso_asignar_proyecto.sql"))
    lista = ", ".join(f"'{c}'" for c in PERFILES_PASE)
    sis = p_int("PAU_SISTEMA_ID")
    verif = f"""-- ############################################################################
-- VERIFICACION PARTE 2
-- ############################################################################
SELECT Verificacion = N'Perfiles homologados', p.CodigoPerfil, p.NombrePerfil, p.PerfilPauId,
       Menus = (SELECT STRING_AGG(m.CodigoMenu, ',') FROM integracion.PauMenu m WHERE m.SistemaId = p.SistemaId AND m.PerfilPauId = p.PerfilPauId AND m.Activo = 1),
       Claims = (SELECT COUNT(*) FROM integracion.PauOperacion o WHERE o.SistemaId = p.SistemaId AND o.PerfilPauId = p.PerfilPauId AND o.Activo = 1)
FROM integracion.PauPerfil p WHERE p.SistemaId = {sis} AND p.Activo = 1 ORDER BY p.CodigoPerfil;
IF (SELECT COUNT(*) FROM integracion.PauPerfil WHERE SistemaId = {sis} AND Activo = 1 AND CodigoPerfil IN ({lista})) <> {len(PERFILES_PASE)}
BEGIN RAISERROR(N'Parte 2: no quedaron homologados los {len(PERFILES_PASE)} perfiles del pase.', 16, 1); SET NOEXEC ON; END
IF EXISTS (SELECT 1 FROM integracion.PauOperacion o JOIN integracion.PauPerfil p ON p.SistemaId = o.SistemaId AND p.PerfilPauId = o.PerfilPauId
           WHERE p.CodigoPerfil = 'P0045' AND o.Activo = 1)
BEGIN RAISERROR(N'Parte 2: P0045 (solo lectura) no debe tener claims.', 16, 1); SET NOEXEC ON; END
GO
"""
    escribir("integracion_pau_ssipe_2_perfiles_y_corte.sql",
             cabecera("integracion_pau_ssipe_2_perfiles_y_corte.sql", desc, params) + valida + INICIO_TX + cuerpo + verif + FIN_TX)


def rollback():
    desc = """ SOLO SI EL PASE FALLA y hay que volver al ingreso por SSO (29R):
   1) back: PauIntegration:Enabled=false y publicar el back y front anteriores;
   2) este script: Asignar Proyecto y los filtros vuelven a leer el SSO.
 Las tablas integracion.* quedan (no afectan al SSO).
"""
    escribir("integracion_pau_ssipe_R_rollback_corte.sql",
             cabecera("integracion_pau_ssipe_R_rollback_corte.sql", desc, [BASE, CONF]) + INICIO_TX
             + adaptar("29R_rollback_corte_identidad_sso.sql") + FIN_TX)


if __name__ == "__main__":
    print("Generando consolidados:")
    parte1()
    parte2()
    rollback()
