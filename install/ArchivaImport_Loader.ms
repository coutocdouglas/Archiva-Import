/*
	Archiva Import - Carregador (instalar UMA vez)

	Copie este arquivo para a pasta de startup do Max:
		maxscript: getDir #startupScripts
	Ele baixa o plugin do GitHub, carrega e se atualiza sozinho a cada abertura do Max.

	>>> Antes de instalar, ajuste o repositorio abaixo (ou use o .ini: [Update] Repo=usuario/repositorio) <<<

	Modo desenvolvimento: no arquivo  getDir #plugcfg + "\MatizImport.ini"  adicione
		[Dev]
		Path=C:\caminho\da\pasta\do\projeto
	e o carregador usa essa pasta local, sem baixar nada.
*/

global MatizLoader
global MatizImport

struct MatizLoaderCore
(
	repo = "coutocdouglas/Archiva-Import",
	branch = "main",
	baseDir = ((getDir #userScripts) + "\\MatizImport"),
	updated = false,

	fn cfgPath = ((getDir #plugcfg) + "\\MatizImport.ini"),
	fn currentDir = (baseDir + "\\current"),

	fn devPath = (getIniSetting (cfgPath()) "Dev" "Path"),

	fn getRepo =
	(
		local v = getIniSetting (cfgPath()) "Update" "Repo"
		if v != "" then v else repo
	),

	fn autoCheck = ((getIniSetting (cfgPath()) "Update" "Auto") != "false"),

	fn mainPath =
	(
		local d = devPath()
		if d != "" then (d + "\\src\\main.ms") else (currentDir() + "\\src\\main.ms")
	),

	fn readText f =
	(
		local l = ""
		if doesFileExist f do
		(
			local s = openFile f
			if s != undefined do
			(
				if not (eof s) do l = readLine s
				close s
			)
		)
		trimRight (trimLeft l)
	),

	fn parseVer s =
	(
		for x in (filterString s ".") collect (
			local n = x as integer
			if n == undefined then 0 else n
		)
	),

	fn isNewer remoteV localV =
	(
		local a = parseVer remoteV
		local b = parseVer localV
		local r = false
		local decided = false
		for i = 1 to (amax #(a.count, b.count)) while not decided do
		(
			local x = if i <= a.count then a[i] else 0
			local y = if i <= b.count then b[i] else 0
			if x > y do (r = true; decided = true)
			if x < y do decided = true
		)
		r
	),

	fn download url dest =
	(
		if doesFileExist dest do deleteFile dest
		local code = 0
		local cmd = "curl.exe -fsSL --max-time 20 -o \"" + dest + "\" \"" + url + "\""
		HiddenDOSCommand cmd exitcode:&code
		(code == 0) and (doesFileExist dest)
	),

	fn remoteVersion =
	(
		local tmp = (getDir #temp) + "\\matiz_version.txt"
		local url = "https://raw.githubusercontent.com/" + (getRepo()) + "/" + branch + "/version.txt"
		if download url tmp then readText tmp else ""
	),

	fn writePs1 ps1 =
	(
		local f = createFile ps1
		format "%\n" "param($zip,$dest)" to:f
		format "%\n" "$ErrorActionPreference='Stop'" to:f
		format "%\n" "try {" to:f
		format "%\n" "$tmp = Join-Path $env:TEMP ('matiz_' + [guid]::NewGuid().ToString('N'))" to:f
		format "%\n" "Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force" to:f
		format "%\n" "$root = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1" to:f
		format "%\n" "$new = $dest + '.new'; $old = $dest + '.old'" to:f
		format "%\n" "if (Test-Path $new) { Remove-Item $new -Recurse -Force }" to:f
		format "%\n" "if (Test-Path $old) { Remove-Item $old -Recurse -Force }" to:f
		format "%\n" "Move-Item -LiteralPath $root.FullName -Destination $new" to:f
		format "%\n" "if (Test-Path $dest) { Move-Item -LiteralPath $dest -Destination $old }" to:f
		format "%\n" "Move-Item -LiteralPath $new -Destination $dest" to:f
		format "%\n" "if (Test-Path $old) { Remove-Item $old -Recurse -Force }" to:f
		format "%\n" "Remove-Item $tmp -Recurse -Force" to:f
		format "%\n" "exit 0" to:f
		format "%\n" "} catch { exit 1 }" to:f
		close f
	),

	fn install =
	(
		makeDir baseDir all:true
		local zip = baseDir + "\\update.zip"
		local ps1 = baseDir + "\\update.ps1"
		local url = "https://github.com/" + (getRepo()) + "/archive/refs/heads/" + branch + ".zip"
		if not (download url zip) do return false
		writePs1 ps1
		local code = 1
		local cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"" + ps1 + "\" \"" + zip + "\" \"" + (currentDir()) + "\""
		HiddenDOSCommand cmd exitcode:&code
		deleteFile zip
		(code == 0) and (doesFileExist (currentDir() + "\\src\\main.ms"))
	),

	fn checkAndUpdate =
	(
		updated = false
		if (devPath()) != "" do return "Modo desenvolvimento ativo (sem atualizacao)."
		local remote = remoteVersion()
		if remote == "" do return "Sem conexao ou repositorio nao encontrado."
		local localV = readText (currentDir() + "\\version.txt")
		if localV != "" and not (isNewer remote localV) do return ("Voce ja esta na versao " + localV + ".")
		if install() then
		(
			updated = true
			"Atualizado para a versao " + remote + "."
		)
		else "Falha ao instalar a atualizacao."
	),

	fn loadMain =
	(
		local p = mainPath()
		if doesFileExist p then (fileIn p; true) else false
	),

	fn startup =
	(
		if (devPath()) != "" then
			loadMain()
		else if not (doesFileExist (mainPath())) then
		(
			checkAndUpdate()
			loadMain()
		)
		else
		(
			loadMain()
			if autoCheck() do
			(
				checkAndUpdate()
				if updated do loadMain()
			)
		)
	)
)

MatizLoader = MatizLoaderCore()
MatizLoader.startup()

macroScript Archiva_Import
	category:"Archiva"
	toolTip:"Archiva Import"
	buttonText:"Archiva Import"
	icon:#("ArchivaImport", 1)
(
	on execute do
	(
		if MatizImport != undefined then MatizImport.openUI()
		else messageBox "Archiva Import nao carregou. Verifique a internet / o repositorio no ArchivaImport_Loader.ms." title:"Archiva Import"
	)
)
