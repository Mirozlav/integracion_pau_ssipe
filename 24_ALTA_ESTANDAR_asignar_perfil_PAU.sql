/*
================================================================================
 SSIPE-PAU - Alta estandar de usuarios (FASE 1 de 2): asignar perfil en PAU
================================================================================
 QUE ES
   Version reutilizable de 18b_asignaciones_usuarios_PAU_PVDPAU_PROD.sql /
   22b_asignaciones_usuarios_excel_PAU_PVDPAU_PROD.sql. Cada vez que llegue un
   lote nuevo de usuarios + perfiles (Documento + nombre + rol SSIPE), este es
   el UNICO archivo que hay que tocar en esta fase: completar la tabla @asig
   con el lote nuevo y ejecutar. No crea usuarios en PAU (eso sigue siendo por
   el portal/front de PAU, nunca por SQL directo: valida PIDE y ~30 columnas).
   Solo asigna, de forma idempotente, el perfil/rol SSIPE a un usuario que YA
   existe en PAU.

 DONDE SE EJECUTA
   PVDPAU_PROD en 10.4.0.20\artemisa20 (ambiente DESA del PAU). PVDSMV es la
   base del SMV, no aplica. Para QA/produccion usar la base PAU equivalente de
   ese ambiente (confirmar nombre antes de correr; no es PVDPAU_PROD fuera de
   DESA).

 CODIGOS DE PERFIL SSIPE VALIDOS HOY EN PAU (ver 19_homologacion_masiva_perfiles_DBSSIPE2.sql):
   P0001 ADMINISTRADOR, P0023 ADMINISTRADOR DE CONTRATO DE OBRA,
   P0024 SUPERVISOR DE OBRA, P0025 COORDINADOR DE OBRA.
   Cualquier otro CodigoSSO (P0021, P0022, P0027..P0046) todavia no esta
   homologado/activo en PAU ni en DBSSIPE2: si el lote nuevo trae uno de esos,
   detenerse y primero completar el 18_alta_masiva_perfiles_SSIPE_en_PAU_PVDPAU_PROD.sql
   + 19_homologacion_masiva_perfiles_DBSSIPE2.sql para ese perfil.

 ATENCION - ARRANCA EN MODO SIMULACION
   @confirmar = 0 corre todo dentro de una transaccion y hace ROLLBACK,
   mostrando en el SELECT final que HARIA con cada fila. Revisar el resultado
   fila por fila (columna Estado) y recien entonces poner @confirmar = 1 y
   volver a ejecutar. Es idempotente: una fila con 'YA TENIA ASIGNACION' no se
   toca aunque se vuelva a correr el mismo lote.

 SIGUIENTE PASO
   Con el Estado = 'ASIGNADO' (o el que ya existia), tomar las columnas
   UsuarioPau y Dependencia de la salida y usarlas como UsuarioPauId /
   DependenciaPauId al llamar integracion.paHomologarUsuariosPau en DBSSIPE2
   (ver 25_SP_paHomologarUsuariosPau_DBSSIPE2.sql).
================================================================================
*/
SET NOCOUNT ON; SET XACT_ABORT ON;
IF DB_NAME() <> N'PVDPAU_PROD' THROW 50001, 'Seleccionar la base PAU del ambiente correcto (ver encabezado).', 1;

DECLARE @confirmar bit = 0;
DECLARE @sis int = 2020;          -- SistemaId de SSIPE en PAU (= PauIntegration:SistemaId en appsettings del back SSIPE). Verificar por ambiente.
DECLARE @usuAuditoria int = 1;    -- USU_PK_USUAR del admin que ejecuta el alta (ajustar segun quien corre el script en ese ambiente)

-- =====> UNICO BLOQUE A EDITAR EN CADA LOTE NUEVO <=====
DECLARE @asig TABLE (Documento varchar(20), NombreCompleto nvarchar(200), CodigoSSO varchar(10));
INSERT @asig VALUES
 -- (N'DNI', N'APELLIDOS Y NOMBRES', N'CodigoSSO')  -- ej: ('41080091', N'LINARES ACOSTA, ABY', 'P0023')
 (N'00000000', N'EJEMPLO - REEMPLAZAR O BORRAR ESTA FILA', 'P0023');
-- =====> FIN DEL BLOQUE A EDITAR <=====

DECLARE @r TABLE (UltimoId int, Mensaje varchar(255), Ok int);
DECLARE @out TABLE (Documento varchar(20), NombreCompleto nvarchar(200), CodigoSSO varchar(10), UsuarioPau int, Dependencia int, Grupo int, Estado varchar(60));
BEGIN TRANSACTION;
DECLARE @doc varchar(20), @nom nvarchar(200), @c varchar(10), @usu int, @den int, @gpr int;
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT Documento, NombreCompleto, CodigoSSO FROM @asig;
OPEN cur; FETCH NEXT FROM cur INTO @doc, @nom, @c;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @usu = (SELECT TOP 1 U.USU_PK_USUAR FROM I_USUARIO_USU U JOIN I_ENTIDAD_ENT E ON E.ENT_PK_ENTID = U.USU_FK_ENTID WHERE E.ENT_V_NRODOC = @doc AND U.USU_B_ESTADO = 1);
    SET @den = (SELECT TOP 1 DEN_PK_DETEN FROM I_DETALLE_ENTIDAD_DEN WHERE DEN_FK_USUAR = @usu AND DEN_B_ESTADO = 1 AND DEN_N_INDICA = 1 ORDER BY DEN_PK_DETEN DESC);
    SET @gpr = (SELECT TOP 1 G.GPR_PK_GPFRL FROM I_GRUPO_PERF_ROL_GPR G JOIN I_ROLES_ROL R ON R.ROL_PK_ROLES = TRY_CONVERT(int, G.GPR_FK_ROLES)
                WHERE G.GPR_FK_SISTE = @sis AND R.ROL_V_CODIGO = @c AND G.GPR_B_ESTADO = 1);
    IF @usu IS NULL INSERT @out VALUES (@doc, @nom, @c, NULL, NULL, NULL, 'USUARIO NO EXISTE EN PAU (registrar por el portal/front primero)');
    ELSE IF @den IS NULL INSERT @out VALUES (@doc, @nom, @c, @usu, NULL, NULL, 'SIN DEPENDENCIA VIGENTE');
    ELSE IF @gpr IS NULL INSERT @out VALUES (@doc, @nom, @c, @usu, @den, NULL, 'PERFIL/ROL NO CREADO EN PAU PARA ESE CodigoSSO (correr 18 primero)');
    ELSE IF EXISTS (SELECT 1 FROM I_DET_USUARIOS_PERMISOS_DUP WHERE DUP_FK_SISTE = @sis AND DUP_FK_USUAR = @usu AND DUP_FK_DETEN = @den AND DUP_N_INDICA = 1)
        INSERT @out VALUES (@doc, @nom, @c, @usu, @den, @gpr, 'YA TENIA ASIGNACION (no se toca)');
    ELSE
    BEGIN
        DELETE @r;
        INSERT @r EXEC SP_INS_DET_USUARIOS_PERMISOS @P_DUP_FK_SISTE = @sis, @P_DUP_FK_DETEN = @den, @P_DUP_FK_USUAR = @usu, @P_DUP_FK_GPRRL = @gpr, @P_DUP_N_INDICA = 1, @P_DUP_N_USUCRE = @usuAuditoria;
        INSERT @out VALUES (@doc, @nom, @c, @usu, @den, @gpr, CASE WHEN EXISTS (SELECT 1 FROM @r WHERE Ok = 1) THEN 'ASIGNADO' ELSE 'ERROR SP' END);
    END
    FETCH NEXT FROM cur INTO @doc, @nom, @c;
END
CLOSE cur; DEALLOCATE cur;
SELECT * FROM @out ORDER BY Estado, Documento;
IF @confirmar = 1 BEGIN COMMIT; PRINT 'COMMIT realizado.'; END
ELSE BEGIN ROLLBACK; PRINT 'Simulacion: ROLLBACK. Revisar Estado por fila y poner @confirmar = 1 para aplicar.'; END
