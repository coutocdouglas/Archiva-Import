; Instalador do Archiva Import
; Instala o plugin na pasta ApplicationPlugins do usuario: vale para todas as versoes do 3ds Max (2024 em diante).
; Nao precisa de administrador.

[Setup]
AppId={{55FDE47C-23CE-4760-8D36-BCF605E7D255}
AppName=Archiva Import
AppVersion=1.0
AppPublisher=Archiva
DefaultDirName={userappdata}\Autodesk\ApplicationPlugins\ArchivaImport.bundle
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename=ArchivaImport_Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\assets\icons\archiva.ico
UninstallDisplayIcon={app}\archiva.ico
UninstallDisplayName=Archiva Import (plugin do 3ds Max)

[Languages]
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Messages]
WelcomeLabel2=Este instalador coloca o plugin Archiva Import no 3ds Max (versao 2024 ou mais nova).%n%nFeche o 3ds Max antes de continuar. Na primeira vez que voce abrir o Max, o plugin baixa a versao mais recente sozinho e depois se atualiza sempre que voce abrir o programa.

[Files]
Source: "PackageContents.xml"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\icons\archiva.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\install\ArchivaImport_Loader.ms"; DestDir: "{app}\post_startup_scripts"; Flags: ignoreversion
; copia do plugin ja dentro do instalador (funciona mesmo sem internet; o GitHub so entrega versoes mais novas)
Source: "..\src\*"; DestDir: "{app}\plugin\src"; Flags: ignoreversion recursesubdirs
Source: "..\assets\*"; DestDir: "{app}\plugin\assets"; Flags: ignoreversion recursesubdirs
Source: "..\version.txt"; DestDir: "{app}\plugin"; Flags: ignoreversion

[Code]
procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
    WizardForm.FinishedLabel.Caption :=
      'Instalacao concluida.' + #13#10 + #13#10 +
      'Abra o 3ds Max (precisa de internet na primeira vez). ' +
      'O botao "Archiva Import" fica em Customize > Customize User Interface > Toolbars, categoria "Archiva".';
end;
