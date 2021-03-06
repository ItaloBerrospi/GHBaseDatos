ALTER PROCEDURE FGEN_SP_GENERACION_RESUMEN_RENOVACIONES
/********************************************************************************/  
/* Procedimiento: FGEN_SP_GENERACION_RESUMEN_RENOVACIONES				       	*/
/* Descripcion  : 													            */ 
/* Encargado    : Luis Bustamante  											    */  
/* Fecha y hora : 20100127														*/ 
/* Version		: 1.0.2															*/ 
/********************************************************************************/ 
(
	@CH_CODIGO_COMPANIA				CHAR(3),
	@IN_CODIGO_RESPONSABLE_UNIDAD	INT ,
	@IN_CODIGO_SEDE					INT,
	@VC_NOMBRE_AREA					VARCHAR(256),
	@VC_TIPO_PROGRAMACION			VARCHAR(256),
	@VC_CORREO						VARCHAR(MAX),
	@NVCABECERARESUMEN				NVARCHAR(MAX),
	@NVCABECERAEXCEL				NVARCHAR(MAX),
	@IN_NUMERO_MENSAJE				INT,
	@IN_CODIGO_AREA					INT
)
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @IN_TOTAL_DIAS_VENCIDOS						INT,
			@IN_TOTAL_DIAS_VENCER_7						INT,
			@IN_TOTAL_DIAS_VENCER_30					INT,
			@IN_TOTAL_DIAS_VENCER_60					INT,
			@IN_TOTAL_DIAS_VENCER_90					INT,
			@IN_DIAS_VENCER_7							INT,
			@IN_DIAS_VENCER_30							INT,
			@IN_DIAS_VENCER_60							INT,
			@IN_DIAS_VENCER_90							INT,
			@IN_CANTIDAD_RENOVAR						INT,
			@VC_FILE_TYPE								VARCHAR(5),
			@VC_SERVER_NAME								VARCHAR(50),
			@VC_DBNAME									VARCHAR(60),
			@VC_RUTA_ADJUNTO							VARCHAR(200),
			@VC_CONTENIDO_ADJUNTAR						VARCHAR(MAX),
			@SY_FOLDER_PATH								sysname,
			@VC_CONTENIDO_ARCHIVO						VARCHAR(MAX),
			@VC_QUERY									VARCHAR(4000),
			@RETURN										VARCHAR(10)
			
	DECLARE	@VC_TABLA_TEMPORAL							VARCHAR(MAX),
			@VC_NOMBRE_ARCHIVO_ADJUNTO					VARCHAR(250),
			@VC_NOMBRE_TABLA_TEMP						VARCHAR(256),
			@IN_DIAS_VENCER_MAX							INT,
			@VC_SEMANAL									VARCHAR(8),
			@VC_MENSUAL									VARCHAR(8)
	-- SETEAR VALORES
		SELECT	@VC_CONTENIDO_ADJUNTAR		=	'',
				@VC_SERVER_NAME				=	@@SERVERNAME,
				@VC_DBNAME					=	DB_NAME(),
				@VC_FILE_TYPE				=	'xls'
	
	EXEC FGEN_SP_OBTENER_VALOR_REF_GENERAL	'089',@CH_CODIGO_COMPANIA,'R04',@VC_SEMANAL OUTPUT
	EXEC FGEN_SP_OBTENER_VALOR_REF_GENERAL	'089',@CH_CODIGO_COMPANIA,'R05',@VC_MENSUAL OUTPUT
	EXEC FGEN_SP_OBTENER_VALOR_REF_GENERAL	'089',@CH_CODIGO_COMPANIA,'R06',@IN_DIAS_VENCER_7 OUTPUT
	EXEC FGEN_SP_OBTENER_VALOR_REF_GENERAL	'089',@CH_CODIGO_COMPANIA,'R07',@IN_DIAS_VENCER_30 OUTPUT
	EXEC FGEN_SP_OBTENER_VALOR_REF_GENERAL	'089',@CH_CODIGO_COMPANIA,'R08',@IN_DIAS_VENCER_60 OUTPUT
	EXEC FGEN_SP_OBTENER_VALOR_REF_GENERAL	'089',@CH_CODIGO_COMPANIA,'R09',@IN_DIAS_VENCER_90 OUTPUT
	
	--Obtener Dias Maximos a vencerse 	
	SELECT @IN_DIAS_VENCER_MAX = CASE @VC_TIPO_PROGRAMACION 
										WHEN @VC_SEMANAL THEN @IN_DIAS_VENCER_7
										WHEN @VC_MENSUAL THEN @IN_DIAS_VENCER_90
										ELSE 0
									END 
	--Obtenemos la Ubicación,donde se van generar los archivos excels para adjuntarse
	EXEC FEMP_SP_OBTENER_VALOR_PARAMETRO '083','09',@SY_FOLDER_PATH OUTPUT
	
	IF RIGHT(@SY_FOLDER_PATH,1) <> '\' SET @SY_FOLDER_PATH = @SY_FOLDER_PATH + '\'
				
	--Obtenemos los totales de dias vencidos o por vencerse
	SELECT @IN_TOTAL_DIAS_VENCIDOS	=	SUM	(	CASE 
												WHEN	NRO_DIAS_VENCIMIENTO_CONTRATO		<=		0	THEN	1
												ELSE	0
												END),
		   @IN_TOTAL_DIAS_VENCER_7	=	SUM	(	CASE 
												WHEN	NRO_DIAS_VENCIMIENTO_CONTRATO BETWEEN 1 AND @IN_DIAS_VENCER_7	THEN	1
												ELSE	0
												END),
		   @IN_TOTAL_DIAS_VENCER_30	=	SUM	(	CASE 
												WHEN	NRO_DIAS_VENCIMIENTO_CONTRATO BETWEEN (@IN_DIAS_VENCER_7+1) AND @IN_DIAS_VENCER_30	THEN	1
												ELSE	0
												END),
		   @IN_TOTAL_DIAS_VENCER_60	=	SUM	(	CASE 
												WHEN	NRO_DIAS_VENCIMIENTO_CONTRATO BETWEEN (@IN_DIAS_VENCER_30+1) AND @IN_DIAS_VENCER_60	THEN	1
												ELSE	0
												END),
		   @IN_TOTAL_DIAS_VENCER_90	=	SUM	(	CASE 
												WHEN	NRO_DIAS_VENCIMIENTO_CONTRATO BETWEEN (@IN_DIAS_VENCER_60+1) AND @IN_DIAS_VENCER_90	THEN	1
												ELSE	0
												END)
	FROM	#TEMPORAL_EMPLEADOS_NOTIFICAR_CONTRATO_A_VENCER
	WHERE	(@IN_CODIGO_RESPONSABLE_UNIDAD = 0 OR IN_CODIGO_RESPONSABLE_UNIDAD	=	@IN_CODIGO_RESPONSABLE_UNIDAD)
		AND	(@IN_CODIGO_SEDE = 0 OR IN_CODIGO_SEDE	=	@IN_CODIGO_SEDE)
		AND (@IN_CODIGO_AREA = 0 OR IN_CODIGO_AREA	=	@IN_CODIGO_AREA)  
	SET @IN_CANTIDAD_RENOVAR =	@IN_TOTAL_DIAS_VENCIDOS + 
								@IN_TOTAL_DIAS_VENCER_7 +  
								@IN_TOTAL_DIAS_VENCER_30+ 
								@IN_TOTAL_DIAS_VENCER_60+	
								@IN_TOTAL_DIAS_VENCER_90	
	
	SET @IN_CANTIDAD_RENOVAR =  ISNULL(@IN_CANTIDAD_RENOVAR,0)
	
	IF @IN_CANTIDAD_RENOVAR <= 0 RETURN --Si no existe vencidas o por vencerse, no generar correo
	--Generamos la tabla resumen
	DECLARE @NVCABECERARESUMEN_CUR NVARCHAR(MAX)
	SET @NVCABECERARESUMEN_CUR = @NVCABECERARESUMEN
	IF @IN_TOTAL_DIAS_VENCIDOS>0 
	SET @NVCABECERARESUMEN_CUR = @NVCABECERARESUMEN_CUR +
		N'<tr align="center">' +
		N'<td>VENCIDAS</td>' +
		N'<td>'+CAST(@IN_TOTAL_DIAS_VENCIDOS AS NVARCHAR(MAX))+'</td>' +
		N'</tr>' 
	IF @IN_TOTAL_DIAS_VENCER_7>0 
	SET @NVCABECERARESUMEN_CUR = @NVCABECERARESUMEN_CUR +
		N'<tr align="center">' +
		N'<td>POR VENCER 7 DIAS</td>'+
		N'<td>'+CAST(@IN_TOTAL_DIAS_VENCER_7 AS NVARCHAR(MAX))+'</td>' +
		N'</tr>'	
	IF @IN_TOTAL_DIAS_VENCER_30>0 
	SET @NVCABECERARESUMEN_CUR = @NVCABECERARESUMEN_CUR +
		N'<tr align="center">' +
		N'<td>POR VENCER 30 DIAS</td>' + 
		N'<td>'+CAST(@IN_TOTAL_DIAS_VENCER_30 AS NVARCHAR(MAX))+'</td>' +
		N'</tr>'	
	IF @IN_TOTAL_DIAS_VENCER_60>0 
	SET @NVCABECERARESUMEN_CUR = @NVCABECERARESUMEN_CUR +
		N'<tr align="center">' +
		N'<td>POR VENCER 60 DIAS</td>' + --REPLACE(N'<td>POR VENCER # DIAS</td>','#',@IN_DIAS_VENCER_MAX) 
		N'<td>'+CAST(@IN_TOTAL_DIAS_VENCER_60 AS NVARCHAR(MAX))+'</td>' +
		N'</tr>'
	IF @IN_TOTAL_DIAS_VENCER_90>0 
	SET @NVCABECERARESUMEN_CUR = @NVCABECERARESUMEN_CUR +
		N'<tr align="center">' +
		N'<td>POR VENCER 90 DIAS</td>'  + --REPLACE(N'<td>POR VENCER # DIAS</td>','#',@IN_DIAS_VENCER_MAX) 
		N'<td>'+CAST(@IN_TOTAL_DIAS_VENCER_90 AS NVARCHAR(MAX))+'</td>' +
		N'</tr>'
	SET @NVCABECERARESUMEN_CUR = @NVCABECERARESUMEN_CUR + 
		N'</table>' 
	--Generamos el resumen
	DECLARE @NVCABECERAEXCEL_CUR NVARCHAR(MAX)
	SET @NVCABECERAEXCEL_CUR  = @NVCABECERAEXCEL

	--SE COMENTA PARA CAMBIAR EL CONTENIDO DEL ADJUNTO

	--SET @NVCABECERAEXCEL_CUR = @NVCABECERAEXCEL_CUR +
	--	CAST ( (SELECT	td = ISNULL(VC_CUC,SPACE(1))				, '',
	--					td = ISNULL(VC_COLABORADOR,SPACE(1))		, '',
	--					td = ISNULL(VC_NOMBRE_PUESTO,SPACE(1))	, '',
	--					td = ISNULL(VC_NOMBRE_AREA,SPACE(1))		, '',
	--					td = ISNULL(VC_NOMBRE_SEDE,SPACE(1))		, '',
	--					td = ISNULL(VC_NOMBRE_RESPONSABLE_UNIDAD,SPACE(1)) , '',
	--					td = ISNULL(CONVERT(VARCHAR(10),DT_FECHA_VENCIMIENTO,103),SPACE(1)) , '',
	--					td = ISNULL(VC_ESTADO,SPACE(1)) , ''
	--			FROM	#TEMPORAL_EMPLEADOS_NOTIFICAR_CONTRATO_A_VENCER
	--			WHERE	(@IN_CODIGO_RESPONSABLE_UNIDAD = 0 OR IN_CODIGO_RESPONSABLE_UNIDAD	=	@IN_CODIGO_RESPONSABLE_UNIDAD)
	--			AND		(@IN_CODIGO_SEDE = 0 OR IN_CODIGO_SEDE	=	@IN_CODIGO_SEDE)
	--			AND		(@IN_CODIGO_AREA = 0 OR IN_CODIGO_AREA	=	@IN_CODIGO_AREA)  
	--			ORDER	BY DT_FECHA_VENCIMIENTO ASC, VC_COLABORADOR ASC
	--	  FOR XML PATH('tr'), TYPE 
	--) AS NVARCHAR(MAX) )
	--SET @NVCABECERAEXCEL_CUR  = @NVCABECERAEXCEL_CUR +
	--	N'</table>'	
	
	--SE COMENTA PARA CAMBIAR EL CONTENIDO DEL ADJUNTO	
		
	-------------------------------
	IF @IN_CODIGO_RESPONSABLE_UNIDAD > 0
	BEGIN
	SET		@VC_NOMBRE_ARCHIVO_ADJUNTO	 = 'Renovacion-Unidad-'+@VC_TIPO_PROGRAMACION+'-'+ CONVERT(VARCHAR,@IN_CODIGO_RESPONSABLE_UNIDAD)+'-'+convert(varchar(8),getdate(),112)+'-'+CONVERT(VARCHAR,@IN_NUMERO_MENSAJE)
	END
	IF @IN_CODIGO_SEDE > 0 
	BEGIN
	SET		@VC_NOMBRE_ARCHIVO_ADJUNTO	 = 'Renovacion-Admin-Desc-'+@VC_TIPO_PROGRAMACION+'-'+ CONVERT(VARCHAR,@IN_CODIGO_SEDE)+'-'+convert(varchar(8),getdate(),112)+'-'+CONVERT(VARCHAR,@IN_NUMERO_MENSAJE)
	END
	IF @IN_CODIGO_RESPONSABLE_UNIDAD = 0 AND @IN_CODIGO_SEDE = 0
	BEGIN
	SET		@VC_NOMBRE_ARCHIVO_ADJUNTO	 = 'Renovacion-Admin-'+@VC_TIPO_PROGRAMACION+'-'+convert(varchar(8),getdate(),112)+'-'+CONVERT(VARCHAR,@IN_NUMERO_MENSAJE)
	END
	--verificamos si existe la tabla TEMP_ARCHIVO
	IF OBJECT_ID('TEMP_ARCHIVO') IS NOT NULL DROP TABLE TEMP_ARCHIVO
	--IF (OBJECT_ID('TEMP_ARCHIVO_' + REPLACE(@VC_NOMBRE_ARCHIVO_ADJUNTO,'-','_')) IS NOT NULL)
	--BEGIN
	--	SET @VC_TABLA_TEMPORAL = 'DROP TABLE TEMP_ARCHIVO_' +  REPLACE(@VC_NOMBRE_ARCHIVO_ADJUNTO,'-','_')
		
	--	EXEC (@VC_TABLA_TEMPORAL)
	--END
	
	----llenamos la tabla TEMP_ARCHIVO con la información que se va adjuntar en un archivo excel
	--SELECT VC_CONTENIDO_ARCHIVO = @NVCABECERAEXCEL_CUR INTO TEMP_ARCHIVO
	--SET	@VC_TABLA_TEMPORAL = ''
	--SET @VC_TABLA_TEMPORAL = 'SELECT VC_CONTENIDO_ARCHIVO = ''' + @NVCABECERAEXCEL_CUR + ''' INTO TEMP_ARCHIVO_' + REPLACE(@VC_NOMBRE_ARCHIVO_ADJUNTO,'-','_')
	--EXEC (@VC_TABLA_TEMPORAL)

	--MODIFICACION CAMBIOS DE CONTENIDO---------------------------------------------------------------------------------------------
	IF (OBJECT_ID('TEMP_ARCHIVO_' + REPLACE(@VC_NOMBRE_ARCHIVO_ADJUNTO,'-','_')) IS NOT NULL)
	BEGIN
		SET @VC_TABLA_TEMPORAL = 'DROP TABLE TEMP_ARCHIVO_' +  REPLACE(@VC_NOMBRE_ARCHIVO_ADJUNTO,'-','_')
		EXEC (@VC_TABLA_TEMPORAL)
	END

	SET @VC_TABLA_TEMPORAL =		'SELECT VC_CUC AS [CUC], 
			VC_COLABORADOR AS [COLABORADOR],
			VC_NOMBRE_PUESTO AS [NOMBRE PUESTO],
			VC_NOMBRE_AREA AS [NOMBRE AREA],
			VC_NOMBRE_SEDE AS [NOMBRE SEDE],
			VC_NOMBRE_RESPONSABLE_UNIDAD AS [NOMBRE RESPONSABLE UNIDAD], 
			CONVERT(VARCHAR(10),DT_FECHA_VENCIMIENTO,103) AS [FECHA VENCIMIENTO],
			VC_ESTADO AS [ESTADO]' + ' INTO TEMP_ARCHIVO_' + REPLACE(@VC_NOMBRE_ARCHIVO_ADJUNTO,'-','_') + ' ' + '
			FROM	#TEMPORAL_EMPLEADOS_NOTIFICAR_CONTRATO_A_VENCER
			WHERE	(' + CONVERT(VARCHAR(32),@IN_CODIGO_RESPONSABLE_UNIDAD) + ' = 0 OR IN_CODIGO_RESPONSABLE_UNIDAD	= ' + CONVERT(VARCHAR(32),@IN_CODIGO_RESPONSABLE_UNIDAD) + ') ' +
			' AND		(' + CONVERT(VARCHAR(32),@IN_CODIGO_SEDE) + ' = 0 OR IN_CODIGO_SEDE	= ' + CONVERT(VARCHAR(32),@IN_CODIGO_SEDE) + ') ' + 
			' AND		(' + CONVERT(VARCHAR(32),@IN_CODIGO_AREA) + ' = 0 OR IN_CODIGO_AREA	= ' + CONVERT(VARCHAR(32),@IN_CODIGO_AREA) + ') ' +	  
			' ORDER	BY DT_FECHA_VENCIMIENTO ASC, VC_COLABORADOR ASC'

	EXEC (@VC_TABLA_TEMPORAL)

	--MODIFICACION CAMBIOS DE CONTENIDO---------------------------------------------------------------------------------------------
	
	--Generamos el archivo adjunto	
	SET @VC_CONTENIDO_ARCHIVO = N'SET NOCOUNT ON SELECT * ' +  'FROM '+ 'TEMP_ARCHIVO_' + REPLACE(@VC_NOMBRE_ARCHIVO_ADJUNTO,'-','_')
	--PROCEDURE PARA INSERTAR MENSAJE CONTENIDO ADJUNTO
	EXEC FGEN_SP_INSERTAR_TA_NOTIFICACION_RENOVACION	@CH_CODIGO_COMPANIA,@VC_CORREO,@NVCABECERARESUMEN_CUR,@VC_CONTENIDO_ADJUNTAR,@VC_RUTA_ADJUNTO,@VC_NOMBRE_AREA,@IN_CANTIDAD_RENOVAR,'1',@VC_CONTENIDO_ARCHIVO,@VC_NOMBRE_ARCHIVO_ADJUNTO
			
END
