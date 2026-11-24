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

	-- ===== organizacao do que foi importado (botoes Grupo / Layer / Lock) =====
	doGroup = false,
	groupName = "Importado",
	doLayer = false,
	layerName = "Importado",
	doLock = false,

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

		doGroup = getBool "Options" "Group" false
		doLayer = getBool "Options" "Layer" false
		doLock = getBool "Options" "Lock" false
		groupName = getIniSetting (cfgPath()) "Options" "GroupName"
		layerName = getIniSetting (cfgPath()) "Options" "LayerName"
		if groupName == "" do groupName = "Importado"
		if layerName == "" do layerName = "Importado"
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
		setIniSetting f "Options" "Group" (doGroup as string)
		setIniSetting f "Options" "GroupName" groupName
		setIniSetting f "Options" "Layer" (doLayer as string)
		setIniSetting f "Options" "LayerName" layerName
		setIniSetting f "Options" "Lock" (doLock as string)
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

	-- ===== organizar: Layer -> Grupo -> Lock (nesta ordem) =====
	fn stepLayer nodes nm =
	(
		local lay = LayerManager.getLayerFromName nm
		if lay == undefined do lay = LayerManager.newLayerFromName nm
		if lay != undefined do
		(
			for o in nodes where isValidNode o do lay.addNode o
		)
		lay
	),

	fn stepGroup nodes nm =
	(
		local valid = for o in nodes where isValidNode o collect o
		if valid.count == 0 do return undefined
		local nm2 = freeName nm undefined
		group valid name:nm2
		getNodeByName nm2
	),

	-- Hierarchy > Link Info > Locks: trava Move, Rotate e Scale em X, Y e Z
	fn stepLock nodes =
	(
		for o in nodes where isValidNode o do setTransformLockFlags o #all
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

		-- opcoes de organizacao (botoes Grupo / Layer / Lock)
		if (doLayer or doGroup or doLock) and objs.count > 0 do
		(
			with undo off
			(
				local nodes = for o in objs where isValidNode o collect o
				local lay = undefined
				local head = undefined
				if doLayer and nodes.count > 0 do
				(
					lay = stepLayer nodes layerName
					if lay != undefined do format "Layer: %\n" layerName to:ss
				)
				if doGroup and nodes.count > 0 do
				(
					head = stepGroup nodes groupName
					if head != undefined then
					(
						if lay != undefined do lay.addNode head
						format "Grupo: % (% objetos)\n" head.name nodes.count to:ss
					)
				)
				if doLock and nodes.count > 0 do
				(
					stepLock nodes
					if head != undefined do stepLock #(head)
					format "Lock: Move/Rotate/Scale travados (Link Info)\n" to:ss
				)
				if head != undefined do objs = #(head)
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

	-- abre a interface (feita em Python/Qt: src\archiva_import)
	fn openUI =
	(
		loadConfig()
		installIcons()
		local root = trimRight MatizImportRoot "\\"
		local launcher = root + "\\archiva_import\\ui.py"
		if not (doesFileExist launcher) then
		(
			messageBox ("Arquivos do plugin nao encontrados:\n" + launcher) title:"Archiva Import"
		)
		else
		(
			python.Execute ("import sys\nr = r'" + root + "'\nif r not in sys.path: sys.path.insert(0, r)")
			python.Execute "[sys.modules.pop(k) for k in list(sys.modules) if k.startswith('archiva_import')]"
			python.Execute "import archiva_import.ui as _archiva_ui\n_archiva_ui.show()"
		)
	)
)

MatizImport = MatizImportCore()
MatizImport.loadConfig()
