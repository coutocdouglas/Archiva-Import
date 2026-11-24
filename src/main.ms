/*
	Archiva Import
	Pipeline de importacao SketchUp (.3ds) -> 3ds Max.

	Etapas: Import -> Collapse -> Weld -> Attach (all in one) -> Detach by ID -> UVW -> Finalizar (Editable Poly + pivo na base).

	A logica das etapas foi portada dos scripts originais (sem janelas, sem depender de selecao):
	- Quick Attach v1.82      - Morozov Anton
	- Weld                    - Vincent Lamy (nothing-is-3d.com)
	- Detach by Material ID   - Jefferson Lim (Terabye Inc. / Shirogumi Inc.)

	Este arquivo e carregado pelo ArchivaImport_Loader.ms.
*/

global MatizImport
global MatizImportRollout
global ArchivaSettingsRollout
global MatizLoader
global MatizImportRoot = getFilenamePath (getThisScriptFilename())

struct MatizImportCore
(
	-- ===== etapas ligadas/desligadas =====
	doCollapse = true,
	doWeld = true,
	doAttach = true,
	doDetach = true,
	doUvw = true,
	doFinish = true,

	-- ===== parametros de cada etapa (valores padrao) =====
	weldThreshold = 0.001,
	chunkSize = 300,
	namingMode = 1,        -- 1 material, 2 objeto, 3 bitmap, 4 numerado
	namePrefix = "",
	propagateMat = true,
	randomColor = true,
	uvwTypeIdx = 1,        -- 1 Box, 2 Planar, 3 Cylindrical, 4 Spherical, 5 Shrink Wrap, 6 Face
	uvwLength = 100.0,
	uvwWidth = 100.0,
	uvwHeight = 100.0,
	uvwRealWorld = true,
	uvwChannel = 1,
	finishPoly = true,
	finishPivot = true,
	pivotMode = 1,         -- 1 base do conjunto (mesmo ponto p/ todos), 2 base de cada objeto

	uvwTypeCodes = #(4, 0, 1, 2, 3, 5),

	fn resetDefaults =
	(
		weldThreshold = 0.001
		chunkSize = 300
		namingMode = 1
		namePrefix = ""
		propagateMat = true
		randomColor = true
		uvwTypeIdx = 1
		uvwLength = 100.0
		uvwWidth = 100.0
		uvwHeight = 100.0
		uvwRealWorld = true
		uvwChannel = 1
		finishPoly = true
		finishPivot = true
		pivotMode = 1
	),

	-- ===== salvar / carregar (plugcfg\MatizImport.ini) =====
	fn cfgPath = ((getDir #plugcfg) + "\\MatizImport.ini"),

	fn getBool sect key def =
	(
		local v = getIniSetting (cfgPath()) sect key
		if v == "" then def else (v == "true")
	),
	fn getNum sect key def =
	(
		local v = getIniSetting (cfgPath()) sect key
		if v == "" then def else
		(
			local n = v as float
			if n == undefined then def else n
		)
	),

	fn loadConfig =
	(
		doCollapse = getBool "Steps" "Collapse" true
		doWeld = getBool "Steps" "Weld" true
		doAttach = getBool "Steps" "Attach" true
		doDetach = getBool "Steps" "Detach" true
		doUvw = getBool "Steps" "Uvw" true
		doFinish = getBool "Steps" "Finish" true

		weldThreshold = getNum "Weld" "Threshold" 0.001
		chunkSize = (getNum "Attach" "ChunkSize" 300) as integer
		namingMode = (getNum "Detach" "NamingMode" 1) as integer
		namePrefix = getIniSetting (cfgPath()) "Detach" "Prefix"
		propagateMat = getBool "Detach" "PropagateMaterials" true
		randomColor = getBool "Detach" "RandomColor" true
		uvwTypeIdx = (getNum "Uvw" "TypeIdx" 1) as integer
		uvwLength = getNum "Uvw" "Length" 100.0
		uvwWidth = getNum "Uvw" "Width" 100.0
		uvwHeight = getNum "Uvw" "Height" 100.0
		uvwRealWorld = getBool "Uvw" "RealWorld" true
		uvwChannel = (getNum "Uvw" "Channel" 1) as integer
		finishPoly = getBool "Finish" "ConvertToPoly" true
		finishPivot = getBool "Finish" "Pivot" true
		pivotMode = (getNum "Finish" "PivotMode" 1) as integer
	),

	fn saveConfig =
	(
		local f = cfgPath()
		setIniSetting f "Steps" "Collapse" (doCollapse as string)
		setIniSetting f "Steps" "Weld" (doWeld as string)
		setIniSetting f "Steps" "Attach" (doAttach as string)
		setIniSetting f "Steps" "Detach" (doDetach as string)
		setIniSetting f "Steps" "Uvw" (doUvw as string)
		setIniSetting f "Steps" "Finish" (doFinish as string)

		setIniSetting f "Weld" "Threshold" (weldThreshold as string)
		setIniSetting f "Attach" "ChunkSize" (chunkSize as string)
		setIniSetting f "Detach" "NamingMode" (namingMode as string)
		setIniSetting f "Detach" "Prefix" namePrefix
		setIniSetting f "Detach" "PropagateMaterials" (propagateMat as string)
		setIniSetting f "Detach" "RandomColor" (randomColor as string)
		setIniSetting f "Uvw" "TypeIdx" (uvwTypeIdx as string)
		setIniSetting f "Uvw" "Length" (uvwLength as string)
		setIniSetting f "Uvw" "Width" (uvwWidth as string)
		setIniSetting f "Uvw" "Height" (uvwHeight as string)
		setIniSetting f "Uvw" "RealWorld" (uvwRealWorld as string)
		setIniSetting f "Uvw" "Channel" (uvwChannel as string)
		setIniSetting f "Finish" "ConvertToPoly" (finishPoly as string)
		setIniSetting f "Finish" "Pivot" (finishPivot as string)
		setIniSetting f "Finish" "PivotMode" (pivotMode as string)
	),

	fn versionText =
	(
		local f = MatizImportRoot + "..\\version.txt"
		local v = "?"
		if doesFileExist f do
		(
			local s = openFile f
			if s != undefined do
			(
				if not (eof s) do v = trimRight (trimLeft (readLine s))
				close s
			)
		)
		v
	),

	-- copia o icone do botao para a pasta de icones do usuario
	fn installIcons =
	(
		try
		(
			local src = MatizImportRoot + "..\\assets\\icons\\"
			local dst = (getDir #userIcons) + "\\"
			for n in #("ArchivaImport_16i.bmp", "ArchivaImport_24i.bmp") do
			(
				if doesFileExist (src + n) do copyFile (src + n) (dst + n)
			)
		)
		catch ()
	),

	-- ===== etapa 1: importar =====
	fn stepImport path =
	(
		local known = #{}
		for o in objects do known[o.inode.handle] = true
		importFile path #noPrompt
		for o in objects where not known[o.inode.handle] collect o
	),

	-- ===== etapa 2: collapse (sem parametros) =====
	fn stepCollapse objs =
	(
		for o in objs where isValidNode o and superclassof o == GeometryClass do
		(
			if classof o != Editable_Poly do convertToPoly o
		)
		for o in objs where isValidNode o and classof o == Editable_Poly collect o
	),

	-- ===== etapa 3: weld =====
	fn weldObj o thr =
	(
		if isValidNode o and classof o == Editable_Poly do
		(
			local n = polyop.getNumVerts o
			if n > 0 do
			(
				o.weldThreshold = thr
				o.EditablePoly.SetSelection #Vertex (#{1..n})
				o.EditablePoly.weldFlaggedVertices()
				o.EditablePoly.SetSelection #Vertex #{}
			)
		)
	),

	-- ===== etapa 4: attach, tudo em uma Editable Poly (em blocos) =====
	fn stepAttach objs =
	(
		local geos = for o in objs where isValidNode o and classof o == Editable_Poly collect o
		if geos.count == 0 do return undefined
		local chunk = amax #(chunkSize, 2)
		while geos.count > 1 do
		(
			local parts = #()
			local b = undefined
			local cnt = 0
			for o in geos do
			(
				if b == undefined or cnt >= chunk do
				(
					b = Editable_Mesh()
					convertTo b Editable_Poly
					b.name = o.name
					append parts b
					cnt = 0
					gc light:true
				)
				polyop.attach b o
				cnt += 1
			)
			geos = parts
		)
		local r = geos[1]
		r.pivot = r.center
		r
	),

	-- ===== etapa 5: detach por Material ID =====
	fn subMatFor mat id =
	(
		if mat == undefined then undefined
		else if classof mat == Multimaterial then
		(
			local k = findItem mat.materialIDList id
			if k > 0 then mat.materialList[k] else undefined
		)
		else mat
	),

	fn bitmapNameFor sub fallback =
	(
		local nm = fallback
		try
		(
			if sub != undefined then
			(
				if classof sub.diffuseMap == Bitmaptexture then nm = getFilenameFile sub.diffuseMap.filename
				else nm = sub.name
			)
		)
		catch ()
		nm
	),

	fn baseNameFor o sub idx =
	(
		local nm = o.name
		case namingMode of
		(
			1: (if sub != undefined do nm = sub.name)
			2: (nm = o.name)
			3: (nm = bitmapNameFor sub o.name)
			4: (nm = idx as string)
		)
		namePrefix + nm
	),

	fn freeName nm self =
	(
		local n = getNodeByName nm
		if n == undefined or n == self then nm else (uniqueName (nm + "_"))
	),

	fn stepDetach o =
	(
		if not (isValidNode o) or classof o != Editable_Poly do return #(o)
		local mat = o.material
		local nf = polyop.getNumFaces o
		local ids = #()
		for f = 1 to nf do appendIfUnique ids (polyop.getFaceMatID o f)
		sort ids

		if ids.count <= 1 do
		(
			local sub = subMatFor mat (if ids.count == 1 then ids[1] else 1)
			o.name = freeName (baseNameFor o sub 1) o
			if propagateMat and sub != undefined do o.material = sub
			return #(o)
		)

		local nodes = #()
		for k = 1 to (ids.count - 1) do
		(
			local sub = subMatFor mat ids[k]
			local nm = freeName (baseNameFor o sub k) undefined
			o.selectByMaterial ids[k]
			local fs = polyop.getFaceSelection o
			if fs.numberSet > 0 do
			(
				polyop.detachFaces o fs delete:true asNode:true name:nm
				local n = getNodeByName nm
				if n != undefined do
				(
					if propagateMat and sub != undefined do n.material = sub
					if randomColor do n.wirecolor = random black white
					append nodes n
				)
			)
		)

		local lastSub = subMatFor mat ids[ids.count]
		o.name = freeName (baseNameFor o lastSub ids.count) o
		if propagateMat and lastSub != undefined do o.material = lastSub
		if randomColor do o.wirecolor = random black white
		append nodes o
		nodes
	),

	-- ===== etapa 6: UVW =====
	fn stepUvw o =
	(
		if isValidNode o and superclassof o == GeometryClass do
		(
			local m = Uvwmap maptype:(uvwTypeCodes[uvwTypeIdx]) length:uvwLength width:uvwWidth height:uvwHeight
			try (m.mapChannel = uvwChannel) catch ()
			try (m.realWorldMapSize = uvwRealWorld) catch ()
			try (o.realWorldMapSize = uvwRealWorld) catch ()
			addModifier o m
		)
	),

	-- ===== etapa final: Editable Poly + pivo na base =====
	fn stepFinish objs =
	(
		local valid = for o in objs where isValidNode o and superclassof o == GeometryClass collect o
		if finishPoly do
		(
			for o in valid do convertToPoly o
		)
		if finishPivot and valid.count > 0 do
		(
			local mn = valid[1].min
			local mx = valid[1].max
			for o in valid do
			(
				mn = [amin mn.x o.min.x, amin mn.y o.min.y, amin mn.z o.min.z]
				mx = [amax mx.x o.max.x, amax mx.y o.max.y, amax mx.z o.max.z]
			)
			local shared = [(mn.x + mx.x) / 2.0, (mn.y + mx.y) / 2.0, mn.z]
			for o in valid do
			(
				if pivotMode == 1 then o.pivot = shared
				else o.pivot = [(o.min.x + o.max.x) / 2.0, (o.min.y + o.max.y) / 2.0, o.min.z]
			)
		)
		valid
	),

	-- ===== pipeline completo =====
	fn run path =
	(
		if not (doesFileExist path) do return "Arquivo nao encontrado."
		local t0 = timeStamp()
		local ss = stringStream ""
		local objs = #()

		with undo off
		(
			with redraw off
			(
				objs = stepImport path
				format "Importados: % objetos\n" objs.count to:ss

				if objs.count > 0 do
				(
					if doCollapse do
					(
						objs = stepCollapse objs
						format "Collapse: % objetos\n" objs.count to:ss
					)
					if doWeld do
					(
						for o in objs do weldObj o weldThreshold
						format "Weld: threshold %\n" weldThreshold to:ss
					)
					if doAttach do
					(
						local b = stepAttach objs
						if b != undefined then
						(
							objs = #(b)
							format "Attach: 1 objeto (% faces)\n" (polyop.getNumFaces b) to:ss
						)
					)
					if doDetach do
					(
						local res = #()
						for o in objs do join res (stepDetach o)
						objs = res
						format "Detach by ID: % objetos\n" objs.count to:ss
					)
					if doUvw do
					(
						for o in objs do stepUvw o
						format "UVW aplicado\n" to:ss
					)
					if doFinish do
					(
						objs = stepFinish objs
						format "Final: Editable Poly e pivo na base\n" to:ss
					)
				)
			)
		)

		if objs.count > 0 do
		(
			select objs
			try (max zoomext sel all) catch ()
		)
		completeRedraw()
		format "Conclu^ido em % s\n" ((timeStamp() - t0) / 1000.0) to:ss
		ss as string
	),

	fn openSettings =
	(
		try (destroyDialog ArchivaSettingsRollout) catch ()
		createDialog ArchivaSettingsRollout bgcolor:(color 22 18 15) fgcolor:(color 241 233 220) style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
	),

	fn openUI =
	(
		try (destroyDialog ArchivaSettingsRollout) catch ()
		try (destroyDialog MatizImportRollout) catch ()
		loadConfig()
		installIcons()
		createDialog MatizImportRollout bgcolor:(color 22 18 15) fgcolor:(color 241 233 220) style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
	)
)

MatizImport = MatizImportCore()
MatizImport.loadConfig()

-- ============================================================
-- Estilo visual (mesma linha do Archiva: grafite quente + pergaminho)
-- ============================================================
global ArchivaUI

-- marcadores: ^c=c cedilha ^1=C cedilha ^a=a til ^2=A til ^o=o til ^e=e agudo ^i=i agudo ^u=u agudo
fn ArchivaTr s =
(
	local C = dotNetClass "System.Char"
	local pairs = #(#("^c", 231), #("^1", 199), #("^a", 227), #("^2", 195), #("^o", 245), #("^e", 233), #("^i", 237), #("^u", 250))
	local r = s
	for p in pairs do r = substituteString r p[1] (C.ConvertFromUtf32 p[2])
	r
)

struct ArchivaUICore
(
	fontColl = undefined,
	fontTried = false,

	fn col r g b = ((dotNetClass "System.Drawing.Color").FromArgb r g b),

	fn ensureFont =
	(
		if not fontTried do
		(
			fontTried = true
			try
			(
				local p = MatizImportRoot + "..\\assets\\fonts\\ZTNature-SemiBold.ttf"
				if doesFileExist p do
				(
					fontColl = dotNetObject "System.Drawing.Text.PrivateFontCollection"
					fontColl.AddFontFile p
				)
			)
			catch (fontColl = undefined)
		)
	),

	fn font size =
	(
		ensureFont()
		local f = undefined
		local sz = size as float
		try (if fontColl != undefined do f = dotNetObject "System.Drawing.Font" (fontColl.Families.GetValue 0) sz) catch ()
		if f == undefined do f = dotNetObject "System.Drawing.Font" "Segoe UI Semibold" sz
		f
	),

	fn styleButton b kind txt =
	(
		b.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
		b.UseVisualStyleBackColor = false
		b.TabStop = false
		b.Cursor = (dotNetClass "System.Windows.Forms.Cursors").Hand
		b.Text = ArchivaTr txt
		case kind of
		(
			#primary:
			(
				b.Font = font 10.5
				b.BackColor = col 240 230 212
				b.ForeColor = col 38 21 12
				b.FlatAppearance.BorderSize = 0
				b.FlatAppearance.MouseOverBackColor = col 247 238 222
				b.FlatAppearance.MouseDownBackColor = col 221 205 178
			)
			#secondary:
			(
				b.Font = font 9.5
				b.BackColor = col 36 31 27
				b.ForeColor = col 241 233 220
				b.FlatAppearance.BorderSize = 1
				b.FlatAppearance.BorderColor = col 58 50 43
				b.FlatAppearance.MouseOverBackColor = col 50 43 37
				b.FlatAppearance.MouseDownBackColor = col 30 25 21
			)
			#header:
			(
				b.Font = font 9.5
				b.BackColor = col 42 34 28
				b.ForeColor = col 227 207 169
				b.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleLeft
				b.Padding = dotNetObject "System.Windows.Forms.Padding" 10 0 0 0
				b.FlatAppearance.BorderSize = 0
				b.FlatAppearance.MouseOverBackColor = col 58 44 34
				b.FlatAppearance.MouseDownBackColor = col 34 27 22
			)
			#link:
			(
				b.Font = font 9
				b.BackColor = col 22 18 15
				b.ForeColor = col 216 194 156
				b.FlatAppearance.BorderSize = 0
				b.FlatAppearance.MouseOverBackColor = col 22 18 15
				b.FlatAppearance.MouseDownBackColor = col 22 18 15
			)
		)
	),

	fn styleLabel l txt size r g b =
	(
		l.AutoSize = false
		l.Text = ArchivaTr txt
		l.Font = font size
		l.ForeColor = col r g b
		l.BackColor = col 22 18 15
	),

	fn styleLog tb =
	(
		tb.Multiline = true
		tb.ReadOnly = true
		tb.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").None
		tb.ScrollBars = (dotNetClass "System.Windows.Forms.ScrollBars").Vertical
		tb.BackColor = col 29 24 20
		tb.ForeColor = col 241 233 220
		tb.Font = font 9
		tb.TabStop = false
	)
)

ArchivaUI = ArchivaUICore()

-- ============================================================
-- Janela de configuracoes (importacao)
-- ============================================================
rollout ArchivaSettingsRollout "Archiva Import - Configuracoes de importacao" width:310
(
	group "Etapas ativas"
	(
		checkbox chkCollapse "Collapse (Editable Poly)"
		checkbox chkWeld "Weld"
		checkbox chkAttach "Attach (all in one mesh)"
		checkbox chkDetach "Detach by ID"
		checkbox chkUvw "UVW Map"
		checkbox chkFinish "Etapa final (Editable Poly + pivo)"
	)
	group "Collapse"
	(
		label lblCol "Sem ajustes (converte tudo para Editable Poly)." align:#left
	)
	group "Weld"
	(
		spinner spnWeld "Threshold: " range:[0.00001, 1000, 0.001] type:#float scale:0.0001 fieldwidth:70 align:#right
	)
	group "Attach (all in one mesh)"
	(
		spinner spnChunk "Objetos por parte: " range:[2, 100000, 300] type:#integer fieldwidth:60 align:#right
		label lblChunk "Se faltar memoria, diminua." align:#left
	)
	group "Detach by ID"
	(
		dropdownlist ddNaming "Nome das pecas:" items:#("Nome do material", "Nome do objeto", "Nome do bitmap", "Numerado")
		edittext edtPrefix "Prefixo: " fieldwidth:200
		checkbox chkProp "Aplicar o material em cada peca"
		checkbox chkRand "Cor de wireframe aleatoria"
	)
	group "UVW Map"
	(
		dropdownlist ddUvw "Tipo:" items:#("Box", "Planar", "Cylindrical", "Spherical", "Shrink Wrap", "Face")
		spinner spnL "Length: " range:[0.001, 1000000, 100] type:#float fieldwidth:70 align:#right
		spinner spnW "Width: " range:[0.001, 1000000, 100] type:#float fieldwidth:70 align:#right
		spinner spnH "Height: " range:[0.001, 1000000, 100] type:#float fieldwidth:70 align:#right
		spinner spnCh "Canal: " range:[1, 99, 1] type:#integer fieldwidth:40 align:#right
		checkbox chkReal "Real-World Map Size"
	)
	group "Etapa final"
	(
		checkbox chkFPoly "Converter tudo para Editable Poly"
		checkbox chkFPiv "Pivo centralizado na base"
		dropdownlist ddPiv "Pivo:" items:#("Mesmo ponto para todos (base do conjunto)", "Base de cada objeto")
	)
	button btnReset "Restaurar padroes" width:140 across:2
	button btnClose "Fechar" width:140

	fn refresh =
	(
		local m = MatizImport
		chkCollapse.checked = m.doCollapse
		chkWeld.checked = m.doWeld
		chkAttach.checked = m.doAttach
		chkDetach.checked = m.doDetach
		chkUvw.checked = m.doUvw
		chkFinish.checked = m.doFinish
		spnWeld.value = m.weldThreshold
		spnChunk.value = m.chunkSize
		ddNaming.selection = m.namingMode
		edtPrefix.text = m.namePrefix
		chkProp.checked = m.propagateMat
		chkRand.checked = m.randomColor
		ddUvw.selection = m.uvwTypeIdx
		spnL.value = m.uvwLength
		spnW.value = m.uvwWidth
		spnH.value = m.uvwHeight
		spnCh.value = m.uvwChannel
		chkReal.checked = m.uvwRealWorld
		chkFPoly.checked = m.finishPoly
		chkFPiv.checked = m.finishPivot
		ddPiv.selection = m.pivotMode
	)

	on ArchivaSettingsRollout open do refresh()

	on chkCollapse changed v do (MatizImport.doCollapse = v; MatizImport.saveConfig())
	on chkWeld changed v do (MatizImport.doWeld = v; MatizImport.saveConfig())
	on chkAttach changed v do (MatizImport.doAttach = v; MatizImport.saveConfig())
	on chkDetach changed v do (MatizImport.doDetach = v; MatizImport.saveConfig())
	on chkUvw changed v do (MatizImport.doUvw = v; MatizImport.saveConfig())
	on chkFinish changed v do (MatizImport.doFinish = v; MatizImport.saveConfig())

	on spnWeld changed v do (MatizImport.weldThreshold = v; MatizImport.saveConfig())
	on spnChunk changed v do (MatizImport.chunkSize = v; MatizImport.saveConfig())
	on ddNaming selected i do (MatizImport.namingMode = i; MatizImport.saveConfig())
	on edtPrefix changed t do (MatizImport.namePrefix = t; MatizImport.saveConfig())
	on chkProp changed v do (MatizImport.propagateMat = v; MatizImport.saveConfig())
	on chkRand changed v do (MatizImport.randomColor = v; MatizImport.saveConfig())
	on ddUvw selected i do (MatizImport.uvwTypeIdx = i; MatizImport.saveConfig())
	on spnL changed v do (MatizImport.uvwLength = v; MatizImport.saveConfig())
	on spnW changed v do (MatizImport.uvwWidth = v; MatizImport.saveConfig())
	on spnH changed v do (MatizImport.uvwHeight = v; MatizImport.saveConfig())
	on spnCh changed v do (MatizImport.uvwChannel = v; MatizImport.saveConfig())
	on chkReal changed v do (MatizImport.uvwRealWorld = v; MatizImport.saveConfig())
	on chkFPoly changed v do (MatizImport.finishPoly = v; MatizImport.saveConfig())
	on chkFPiv changed v do (MatizImport.finishPivot = v; MatizImport.saveConfig())
	on ddPiv selected i do (MatizImport.pivotMode = i; MatizImport.saveConfig())

	-- restaura so os parametros (as etapas ligadas/desligadas ficam como estao)
	on btnReset pressed do
	(
		MatizImport.resetDefaults()
		MatizImport.saveConfig()
		refresh()
	)
	on btnClose pressed do destroyDialog ArchivaSettingsRollout
)

-- ============================================================
-- Janela principal: categorias recolhiveis (Importacao / Texturas / Luzes)
-- ============================================================
rollout MatizImportRollout "Archiva Import" width:300
(
	local secOpen = #(true, false, false)

	dotNetControl pbLogo "System.Windows.Forms.PictureBox" pos:[14, 10] width:34 height:34
	dotNetControl lblTitle "System.Windows.Forms.Label" pos:[56, 9] width:230 height:22
	dotNetControl lblVer "System.Windows.Forms.Label" pos:[56, 30] width:230 height:16

	-- categoria 1: importacao
	dotNetControl hdrImp "System.Windows.Forms.Button" pos:[12, 60] width:276 height:32
	dotNetControl btnImport "System.Windows.Forms.Button" pos:[12, 100] width:276 height:38
	dotNetControl btnCfg "System.Windows.Forms.Button" pos:[12, 140] width:276 height:32
	dotNetControl tbLog "System.Windows.Forms.TextBox" pos:[12, 180] width:276 height:120

	-- categoria 2: texturas
	dotNetControl hdrTex "System.Windows.Forms.Button" pos:[12, 310] width:276 height:32
	dotNetControl lblTex "System.Windows.Forms.Label" pos:[12, 350] width:276 height:48

	-- categoria 3: luzes
	dotNetControl hdrLuz "System.Windows.Forms.Button" pos:[12, 400] width:276 height:32
	dotNetControl lblLuz "System.Windows.Forms.Label" pos:[12, 440] width:276 height:24

	dotNetControl btnUpdate "System.Windows.Forms.Button" pos:[12, 470] width:276 height:26

	fn loadOpenState =
	(
		local s = getIniSetting (MatizImport.cfgPath()) "Ui" "SecOpen"
		if s.count == 3 do
		(
			for i = 1 to 3 do secOpen[i] = ((substring s i 1) == "1")
		)
	)

	fn saveOpenState =
	(
		local s = ""
		for i = 1 to 3 do s += (if secOpen[i] then "1" else "0")
		setIniSetting (MatizImport.cfgPath()) "Ui" "SecOpen" s
	)

	fn relayout =
	(
		local hdr = #(hdrImp, hdrTex, hdrLuz)
		local cont = #(#(btnImport, btnCfg, tbLog), #(lblTex), #(lblLuz))
		local titles = #("IMPORTA^1^2O", "TEXTURAS", "LUZES")
		local y = 58
		for s = 1 to 3 do
		(
			local h = hdr[s]
			h.Left = 12
			h.Top = y
			h.Text = ArchivaTr ((if secOpen[s] then "-   " else "+   ") + titles[s])
			y += h.Height + 6
			for c in cont[s] do
			(
				c.Visible = secOpen[s]
				if secOpen[s] do
				(
					c.Left = 12
					c.Top = y
					y += c.Height + 6
				)
			)
			y += 4
		)
		btnUpdate.Left = 12
		btnUpdate.Top = y
		y += btnUpdate.Height + 8
		MatizImportRollout.height = y
	)

	on MatizImportRollout open do
	(
		-- logo + titulo
		try
		(
			local lp = MatizImportRoot + "..\\assets\\brand\\logo64.png"
			if doesFileExist lp do
			(
				pbLogo.Image = (dotNetClass "System.Drawing.Image").FromFile lp
				pbLogo.SizeMode = (dotNetClass "System.Windows.Forms.PictureBoxSizeMode").Zoom
			)
		)
		catch ()
		pbLogo.BackColor = ArchivaUI.col 22 18 15
		ArchivaUI.styleLabel lblTitle "Archiva Import" 14 241 233 220
		ArchivaUI.styleLabel lblVer ("v" + MatizImport.versionText() + "  -  importa^c^ao do SketchUp") 8.5 168 156 140

		ArchivaUI.styleButton hdrImp #header ""
		ArchivaUI.styleButton hdrTex #header ""
		ArchivaUI.styleButton hdrLuz #header ""
		ArchivaUI.styleButton btnImport #primary "IMPORTAR .3DS..."
		ArchivaUI.styleButton btnCfg #secondary "Configura^c^oes de importa^c^ao..."
		ArchivaUI.styleLog tbLog
		ArchivaUI.styleLabel lblTex "Em breve: trocar os materiais do SketchUp pelos da sua biblioteca, pelo nome." 9 168 156 140
		ArchivaUI.styleLabel lblLuz "Em breve." 9 168 156 140
		ArchivaUI.styleButton btnUpdate #link "Verificar atualiza^c^oes"

		loadOpenState()
		relayout()
	)

	on hdrImp Click s e do (secOpen[1] = not secOpen[1]; saveOpenState(); relayout())
	on hdrTex Click s e do (secOpen[2] = not secOpen[2]; saveOpenState(); relayout())
	on hdrLuz Click s e do (secOpen[3] = not secOpen[3]; saveOpenState(); relayout())

	on btnCfg Click s e do MatizImport.openSettings()

	on btnImport Click s e do
	(
		local f = getOpenFileName caption:"Importar arquivo 3DS" types:"3DS (*.3ds)|*.3ds|Todos (*.*)|*.*|"
		if f != undefined do
		(
			MatizImport.loadConfig()
			tbLog.Text = "Importando..."
			tbLog.Refresh()
			local rep = MatizImport.run f
			tbLog.Text = ArchivaTr (substituteString rep "\n" "\r\n")
		)
	)

	on btnUpdate Click s e do
	(
		if MatizLoader == undefined then
			tbLog.Text = "Carregador nao encontrado. Reinstale o Archiva Import."
		else
		(
			tbLog.Text = "Verificando..."
			tbLog.Refresh()
			local msg = MatizLoader.checkAndUpdate()
			if MatizLoader.updated do
			(
				MatizLoader.loadMain()
				msg += " Reabra o plugin para usar a nova versao."
			)
			tbLog.Text = msg
		)
	)
)
