"""
Arma los scripts consolidados del pase PAU -> SSIPE para la base SSIPE del ambiente, a partir de los
scripts fuente de esta carpeta (no se editan a mano: si cambia un fuente, volver a correr esto):

  PASE_QA_PROD/integracion_pau_ssipe_1_estructura.sql
      P01 + 27 + 28 + 25. Esquema integracion, SPs de sesion/directorio, vista de identidad,
      catalogo de areas y SP de homologacion de usuarios. No necesita datos del PAU.
      Es prerrequisito de DESPLIEGUE_1_DBSSIPE.sql. No cambia el comportamiento del back anterior.

  PASE_QA_PROD/integracion_pau_ssipe_2_perfiles_y_corte.sql
      P02 + 30 + 29. Homologa perfiles/menus/claims con los ids del PAU del ambiente y hace el
      corte de identidad (Asignar Proyecto y filtros leen PAU). Va despues de DESPLIEGUE_1 y en la
      MISMA ventana en que se publican el back/front de dev_pau.

  PASE_QA_PROD/integracion_pau_ssipe_R_rollback_corte.sql
      29R. Solo si hay que volver al SSO (junto con PauIntegration:Enabled=false en el back).

Cada consolidado:
  - Se ejecuta en modo SQLCMD (SSMS: Consulta > Modo SQLCMD, o sqlcmd -b). Si no, no ejecuta nada.
  - Corta ante el primer error (:on error exit).
  - Corre en UNA transaccion exterior: CONFIRMAR=0 simula todo y hace ROLLBACK; CONFIRMAR=1 confirma.
    Los @confirmar internos de P02/30 quedan en 1 y solo anidan en esa transaccion.
  - Guarda de base unica: variable BASE_SSIPE.

Uso:  python armar_integracion_pau_ssipe.py
"""
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "PASE_QA_PROD"

PERFILES_PASE = ["P0001", "P0023", "P0024", "P0025", "P0028", "P0029", "P0045"]
MODULOS = [("2182", "M0001"), ("2183", "M0007"), ("2184", "M0043"), ("2185", "M1051")]


def leer(rel):
    texto = (RAIZ / rel).read_text(encoding="ascii").replace("\r\n", "\n")
    return texto


def reemplazar(texto, viejo, nuevo, veces=1, regex=False):
    n = len(re.findall(viejo, texto)) if regex else texto.count(viejo)
    if n != veces:
        raise SystemExit(f"Se esperaban {veces} coincidencias de {viejo!r} y hay {n}: revisar el fuente.")
    return re.sub(viejo, lambda _: nuevo, texto) if regex else texto.replace(viejo, nuevo)


def adaptar(rel, texto=None):
    """Guarda por variable, sin SET NOEXEC OFF intermedios, @confirmar interno en 1."""
    t = leer(rel) if texto is None else texto
    t = reemplazar(t, r"IF DB_NAME\(\) <> N'DBSSIPE2?'[^\n]*", "IF DB_NAME() <> N'$(BASE_SSIPE)'", regex=True)
    t = re.sub(r"(?m)^SET NOEXEC OFF;[ \t]*\n", "", t)
    t = t.replace("DECLARE @confirmar bit = 0;",
                  "DECLARE @confirmar bit = 1;   -- consolidado: lo decide la transaccion exterior (CONFIRMAR)")
    t = t.replace("PRINT 'COMMIT realizado.';", "PRINT 'Bloque OK (se confirma o revierte al final segun CONFIRMAR).';")
    barra = "-- " + "#" * 76
    return f"{barra}\n-- FUENTE: {rel}\n{barra}\n{t.rstrip()}\nGO\n"


def cabecera(titulo, descripcion, variables):
    setvars = "\n".join(f':setvar {k} "{v}"{" " * max(1, 24 - len(k) - len(v))}-- {c}' for k, v, c in variables)
    return f"""/*
================================================================================
 {titulo}
================================================================================
{descripcion}
 COMO SE EJECUTA
   - Modo SQLCMD obligatorio (SSMS: menu Consulta > Modo SQLCMD; o sqlcmd -b -I).
     Sin SQLCMD no ejecuta nada.
   - Conectado a la base SSIPE del ambiente, con una cuenta con permisos DDL.
   - Primero con CONFIRMAR "0" (simula todo y hace ROLLBACK). Revisar la salida.
     Luego CONFIRMAR "1" en una conexion nueva.
   - Corta ante el primer error; si corta, la transaccion se revierte completa.
 GENERADO por herramientas/armar_integracion_pau_ssipe.py: no editar a mano,
 salvo el bloque :setvar de abajo.
================================================================================
*/
:on error exit
{setvars}
GO
IF N'$(__MODO_SQLCMD)' <> N'SI'
BEGIN RAISERROR(N'Ejecutar en modo SQLCMD (SSMS: Consulta > Modo SQLCMD). No se ejecuto nada.', 16, 1); SET NOEXEC ON; END
GO
IF DB_NAME() <> N'$(BASE_SSIPE)' OR N'$(CONFIRMAR)' NOT IN (N'0', N'1')
BEGIN RAISERROR(N'Base distinta de BASE_SSIPE o CONFIRMAR distinto de 0/1: ejecucion cancelada.', 16, 1); SET NOEXEC ON; END
GO
"""


INICIO_TX = """SET XACT_ABORT ON;
BEGIN TRANSACTION;
PRINT CONCAT(N'Inicio en ', @@SERVERNAME, N'.', DB_NAME(), N' | CONFIRMAR=$(CONFIRMAR) | ', CONVERT(varchar(19), SYSDATETIME(), 120));
GO
"""

FIN_TX = """-- ############################################################################
-- CIERRE: confirma o revierte todo lo anterior
-- ############################################################################
IF @@TRANCOUNT <> 1
BEGIN RAISERROR(N'Transaccion exterior inconsistente: se revierte.', 16, 1); IF @@TRANCOUNT > 0 ROLLBACK; SET NOEXEC ON; END
GO
IF $(CONFIRMAR) = 1 BEGIN COMMIT; PRINT N'COMMIT REALIZADO.'; END
ELSE BEGIN ROLLBACK; PRINT N'SIMULACION: ROLLBACK de todo. Revisar la salida y repetir con CONFIRMAR "1" en una conexion nueva.'; END
GO
SET NOEXEC OFF;
GO
"""

MODO = ("__MODO_SQLCMD", "SI", "no tocar")


def escribir(nombre, texto):
    ruta = SALIDA / nombre
    texto.encode("ascii")
    ruta.write_bytes(texto.replace("\r\n", "\n").replace("\n", "\r\n").encode("ascii"))
    print(f"  {ruta.relative_to(RAIZ)}  ({texto.count(chr(10))} lineas)")


def parte1():
    desc = """ PASE PAU -> SSIPE, PARTE 1 de 2 (estructura). Base SSIPE del ambiente.
   P01 esquema integracion + tablas | 27 SPs de sesion y directorio PAU
   28 vista integracion.vw_UsuarioSsipe + integracion.paListarArea
   25 SP integracion.paHomologarUsuariosPau (v2)
 No necesita ids del PAU ni cambia el comportamiento del back actual.
 Es PRERREQUISITO de DESPLIEGUE_1_DBSSIPE.sql (sus listados leen la vista).
 Previo: P00_precheck_QA_PROD.sql con el usuario del back (ListoParaPase=1).
"""
    vars_ = [MODO, ("BASE_SSIPE", "DBSSIPE", "base SSIPE del ambiente"),
             ("CONFIRMAR", "0", "0 = simular, 1 = aplicar")]
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
             cabecera("integracion_pau_ssipe_1_estructura.sql", desc, vars_) + INICIO_TX + cuerpo + verif + FIN_TX)


def parte2():
    desc = """ PASE PAU -> SSIPE, PARTE 2 de 2 (perfiles y corte). Base SSIPE del ambiente.
   P02 perfiles/menus/claims SSIPE con los ids del PAU del ambiente
       (P0001, P0023, P0024, P0025, P0028, P0029 y P0045 LECTOR GENERAL = "Seguimiento", solo lectura)
   30  11 claims de Ejecucion CVA (reemplaza el bloque 2 de DESPLIEGUE_2_DBSSO)
   29  corte de identidad: Asignar Proyecto y filtros de listados leen PAU
 Requiere: parte 1 y DESPLIEGUE_1_DBSSIPE.sql aplicados, y los ids que entrega el
 equipo PAU al correr P03_sistema_modulos_perfiles_SSIPE_en_PAU.sql en el PAU.
 Ejecutar en la MISMA ventana en que se publican back y front (rama dev_pau).
 Rollback: integracion_pau_ssipe_R_rollback_corte.sql + PauIntegration:Enabled=false.
"""
    vars_ = [MODO, ("BASE_SSIPE", "DBSSIPE", "base SSIPE del ambiente"),
             ("CONFIRMAR", "0", "0 = simular, 1 = aplicar"),
             ("PAU_SISTEMA_ID", "NULL", "P03 'sistema': SistemaId (= PauIntegration:SistemaId)")]
    vars_ += [(f"PAU_PERFIL_{c}", "NULL", f"P03 'resultado': PerfilPauId de {c}") for c in PERFILES_PASE]
    vars_ += [(f"PAU_MODULO_{m}", "NULL", f"P03 'modulos': ModuloPauId de {m}") for _, m in MODULOS]
    faltan = " OR ".join(f"TRY_CONVERT(int, N'$({k})') IS NULL" for k, _, _ in vars_[3:])
    valida = f"""IF {faltan}
BEGIN RAISERROR(N'Completar en :setvar los ids del PAU del ambiente (salida de P03). No se ejecuto nada.', 16, 1); SET NOEXEC ON; END
GO
"""
    p02 = leer("PASE_QA_PROD/P02_homologacion_perfiles_QA_PROD.sql")
    p02 = reemplazar(p02, "DECLARE @SistemaId int = NULL;", "DECLARE @SistemaId int = $(PAU_SISTEMA_ID);")
    for c in PERFILES_PASE:
        p02 = reemplazar(p02, f"('{c}', NULL,", f"('{c}', $(PAU_PERFIL_{c}),")
    for desa, m in MODULOS:
        p02 = reemplazar(p02, f"(N'{desa}', '{m}', NULL)", f"(N'{desa}', '{m}', N'$(PAU_MODULO_{m})')")
    cuerpo = (adaptar("PASE_QA_PROD/P02_homologacion_perfiles_QA_PROD.sql", p02)
              + adaptar("30_claims_ejecucion_cva_PAU.sql")
              + adaptar("29_corte_identidad_sso_asignar_proyecto.sql"))
    lista = ", ".join(f"'{c}'" for c in PERFILES_PASE)
    verif = f"""-- ############################################################################
-- VERIFICACION PARTE 2
-- ############################################################################
SELECT Verificacion = N'Perfiles homologados', p.CodigoPerfil, p.NombrePerfil, p.PerfilPauId,
       Menus = (SELECT STRING_AGG(m.CodigoMenu, ',') FROM integracion.PauMenu m WHERE m.SistemaId = p.SistemaId AND m.PerfilPauId = p.PerfilPauId AND m.Activo = 1),
       Claims = (SELECT COUNT(*) FROM integracion.PauOperacion o WHERE o.SistemaId = p.SistemaId AND o.PerfilPauId = p.PerfilPauId AND o.Activo = 1)
FROM integracion.PauPerfil p WHERE p.SistemaId = $(PAU_SISTEMA_ID) AND p.Activo = 1 ORDER BY p.CodigoPerfil;
IF (SELECT COUNT(*) FROM integracion.PauPerfil WHERE SistemaId = $(PAU_SISTEMA_ID) AND Activo = 1 AND CodigoPerfil IN ({lista})) <> {len(PERFILES_PASE)}
BEGIN RAISERROR(N'Parte 2: no quedaron homologados los {len(PERFILES_PASE)} perfiles del pase.', 16, 1); SET NOEXEC ON; END
IF EXISTS (SELECT 1 FROM integracion.PauOperacion o JOIN integracion.PauPerfil p ON p.SistemaId = o.SistemaId AND p.PerfilPauId = o.PerfilPauId
           WHERE p.CodigoPerfil = 'P0045' AND o.Activo = 1)
BEGIN RAISERROR(N'Parte 2: P0045 (solo lectura) no debe tener claims.', 16, 1); SET NOEXEC ON; END
GO
"""
    escribir("integracion_pau_ssipe_2_perfiles_y_corte.sql",
             cabecera("integracion_pau_ssipe_2_perfiles_y_corte.sql", desc, vars_) + valida + INICIO_TX + cuerpo + verif + FIN_TX)


def rollback():
    desc = """ ROLLBACK del corte (29R). Solo si hay que volver al ingreso por SSO:
   1) back: PauIntegration:Enabled=false y publicar el back anterior;
   2) este script: Asignar Proyecto y los filtros vuelven a leer el SSO.
 Las tablas integracion.* quedan (no afectan al SSO).
"""
    vars_ = [MODO, ("BASE_SSIPE", "DBSSIPE", "base SSIPE del ambiente"),
             ("CONFIRMAR", "0", "0 = simular, 1 = aplicar")]
    escribir("integracion_pau_ssipe_R_rollback_corte.sql",
             cabecera("integracion_pau_ssipe_R_rollback_corte.sql", desc, vars_) + INICIO_TX
             + adaptar("29R_rollback_corte_identidad_sso.sql") + FIN_TX)


if __name__ == "__main__":
    print("Generando consolidados:")
    parte1()
    parte2()
    rollback()
