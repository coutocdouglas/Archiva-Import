/*
	Archiva Import
	Pipeline de importacao SketchUp (.3ds) -> 3ds Max.

	Etapas: Import -> Collapse -> Weld -> Attach (all in one) -> Detach by ID (nome do material) -> UVW Box.

	A logica das etapas foi portada dos scripts originais (sem janelas, sem depender de selecao):
	- Quick Attach v1.82      - Morozov Anton
	- Weld                    - Vincent Lamy (nothing-is-3d.com)
	- Detach by Material ID   - Jefferson Lim (Terabye Inc. / Shirogumi Inc.)

	Este arquivo e carregado pelo ArchivaImport_Loader.ms (veja install/).
*/

global MatizImport
global MatizImportRollout
global MatizLoader
global MatizImportRoot = getFilenamePath (getThisScriptFilename())

struct MatizImportCore
(
	-- ===== configuracoes (salvas em plugcfg\MatizImport.ini) =====
	weldThreshold = 0.001,
	doCollapse = true,
	doWeld = true,
	doAttach = true,
	doDetach = true,
	doUvw = true,
	uvwSize = 100.0,
	chunkSize = 300,

	fn cfgPath = ((getDir #plugcfg) + "\\MatizImport.ini"),

	fn getBool sect key def =
	(
		local v = getIniSetting (cfgPath()) sect key
		if v == "" then def else (v == "true")
	),

	fn loadConfig =
	(
		local f = cfgPath()
		local v = getIniSetting f "Import" "WeldThreshold"
		if v != "" do weldThreshold = v as float
		v = getIniSetting f "Import" "UvwSize"
		if v != "" do uvwSize = v as float
		doCollapse = getBool "Steps" "Collapse" true
		doWeld = getBool "Steps" "Weld" true
		doAttach = getBool "Steps" "Attach" true
		doDetach = getBool "Steps" "Detach" true
		doUvw = getBool "Steps" "Uvw" true
	),

	fn saveConfig =
	(
		local f = cfgPath()
		setIniSetting f "Import" "WeldThreshold" (weldThreshold as string)
		setIniSetting f "Import" "UvwSize" (uvwSize as string)
		setIniSetting f "Steps" "Collapse" (doCollapse as string)
		setIniSetting f "Steps" "Weld" (doWeld as string)
		setIniSetting f "Steps" "Attach" (doAttach as string)
		setIniSetting f "Steps" "Detach" (doDetach as string)
		setIniSetting f "Steps" "Uvw" (doUvw as string)
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

	-- ===== etapa 1: importar =====
	fn stepImport path =
	(
		local known = #{}
		for o in objects do known[o.inode.handle] = true
		importFile path #noPrompt
		for o in objects where not known[o.inode.handle] collect o
	),

	-- ===== etapa 2: collapse =====
	fn stepCollapse objs =
	(
		for o in objs where isValidNode o and superclassof o == GeometryClass do
		(
			if classof o != Editable_Poly do convertToPoly o
		)
		for o in objs where isValidNode o and classof o == Editable_Poly collect o
	),

	-- ===== etapa 3: weld (metodo do script original) =====
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

	-- ===== etapa 4: attach, tudo em uma Editable Poly (em blocos de chunkSize) =====
	fn stepAttach objs =
	(
		local geos = for o in objs where isValidNode o and classof o == Editable_Poly collect o
		if geos.count == 0 do return undefined
		while geos.count > 1 do
		(
			local parts = #()
			local b = undefined
			local cnt = 0
			for o in geos do
			(
				if b == undefined or cnt >= chunkSize do
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

	-- ===== etapa 5: detach por Material ID, nomeando pelo material =====
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

		-- 0 ou 1 ID: nao ha o que separar, so nomeia pelo material
		if ids.count <= 1 do
		(
			local sub = subMatFor mat (if ids.count == 1 then ids[1] else 1)
			if sub != undefined do
			(
				o.name = freeName sub.name o
				o.material = sub
			)
			return #(o)
		)

		local nodes = #()
		for k = 1 to (ids.count - 1) do
		(
			local sub = subMatFor mat ids[k]
			local nm = if sub != undefined then sub.name else o.name
			nm = freeName nm undefined
			o.selectByMaterial ids[k]
			local fs = polyop.getFaceSelection o
			if fs.numberSet > 0 do
			(
				polyop.detachFaces o fs delete:true asNode:true name:nm
				local n = getNodeByName nm
				if n != undefined do
				(
					if sub != undefined do n.material = sub
					n.wirecolor = random black white
					append nodes n
				)
			)
		)

		-- o que sobrou no objeto original vira o ultimo ID
		local lastSub = subMatFor mat ids[ids.count]
		if lastSub != undefined do
		(
			o.name = freeName lastSub.name o
			o.material = lastSub
		)
		o.wirecolor = random black white
		append nodes o
		nodes
	),

	-- ===== etapa 6: UVW Map Box (Real-World) =====
	fn stepUvw o =
	(
		if isValidNode o and superclassof o == GeometryClass do
		(
			local m = Uvwmap maptype:4 length:uvwSize width:uvwSize height:uvwSize
			try (m.realWorldMapSize = true) catch ()
			try (o.realWorldMapSize = true) catch ()
			addModifier o m
		)
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
						format "UVW Box %: aplicado\n" uvwSize to:ss
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
		format "Concluido em % s\n" ((timeStamp() - t0) / 1000.0) to:ss
		ss as string
	),

	fn openUI =
	(
		try (destroyDialog MatizImportRollout) catch ()
		loadConfig()
		createDialog MatizImportRollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
	)
)

MatizImport = MatizImportCore()
MatizImport.loadConfig()

rollout MatizImportRollout "Archiva Import" width:250
(
	button btnImport "IMPORTAR .3DS..." width:230 height:34 align:#center
	group "Etapas"
	(
		checkbox chkCollapse "Collapse (Editable Poly)"
		checkbox chkWeld "Weld"
		spinner spnWeld "Threshold: " range:[0.00001, 1000, 0.001] type:#float scale:0.0001 fieldwidth:60 align:#right
		checkbox chkAttach "Attach (all in one mesh)"
		checkbox chkDetach "Detach by ID (nome do material)"
		checkbox chkUvw "UVW Map Box (Real-World)"
		spinner spnUvw "Tamanho: " range:[0.001, 100000, 100] type:#float fieldwidth:60 align:#right
	)
	edittext edtLog "" readOnly:true height:90 width:236 align:#center
	button btnUpdate "Verificar atualizacoes" width:230 align:#center
	label lblVer "" align:#center

	on MatizImportRollout open do
	(
		chkCollapse.checked = MatizImport.doCollapse
		chkWeld.checked = MatizImport.doWeld
		spnWeld.value = MatizImport.weldThreshold
		chkAttach.checked = MatizImport.doAttach
		chkDetach.checked = MatizImport.doDetach
		chkUvw.checked = MatizImport.doUvw
		spnUvw.value = MatizImport.uvwSize
		lblVer.caption = "v" + MatizImport.versionText()
	)

	on chkCollapse changed v do (MatizImport.doCollapse = v; MatizImport.saveConfig())
	on chkWeld changed v do (MatizImport.doWeld = v; MatizImport.saveConfig())
	on spnWeld changed v do (MatizImport.weldThreshold = v; MatizImport.saveConfig())
	on chkAttach changed v do (MatizImport.doAttach = v; MatizImport.saveConfig())
	on chkDetach changed v do (MatizImport.doDetach = v; MatizImport.saveConfig())
	on chkUvw changed v do (MatizImport.doUvw = v; MatizImport.saveConfig())
	on spnUvw changed v do (MatizImport.uvwSize = v; MatizImport.saveConfig())

	on btnImport pressed do
	(
		local f = getOpenFileName caption:"Importar arquivo 3DS" types:"3DS (*.3ds)|*.3ds|Todos (*.*)|*.*|"
		if f != undefined do
		(
			edtLog.text = "Importando..."
			local rep = MatizImport.run f
			edtLog.text = substituteString rep "\n" "\r\n"
		)
	)

	on btnUpdate pressed do
	(
		if MatizLoader == undefined then
			edtLog.text = "Carregador nao encontrado. Reinstale o ArchivaImport_Loader.ms."
		else
		(
			edtLog.text = "Verificando..."
			local msg = MatizLoader.checkAndUpdate()
			if MatizLoader.updated do
			(
				MatizLoader.loadMain()
				msg += " Reabra o plugin para usar a nova versao."
			)
			edtLog.text = msg
		)
	)
)
