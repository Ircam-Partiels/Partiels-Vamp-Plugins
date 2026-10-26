; Inno Setup script of the installer of a single plugin.
; The plugin is defined with the command line options of iscc:
;  - MyPluginName: the name of the plugin (e.g. Crepe).
;  - MyPluginVerName: the version of the plugin (e.g. 5.0.0), the installer
;    is versioned with the version of the plugin (and not with the version
;    of the bundle of the plugins).
;  - MyPluginAltName: the alternative (ircam-formatted) name of the plugin (e.g. ircamcrepe).
;  - MyPluginBundleName: the name of the .vamp bundle of the plugin including the extension (e.g. ircamcrepe.vamp),
;    only defined if the plugin is distributed as a bundle (otherwise the legacy
;    library and cat files of the plugin are used).
;  - MyPluginLegacyModels: the directory of the models of the previous versions of the plugin
;    in the ProgramData\Ircam directory (e.g. whispermodels), only defined if the plugin has legacy models.
#define MyAppName "Partiels Vamp Plugins"
#define MyAppPublisher "Ircam"
#define MyAppURL "www.ircam.fr"

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; The AppId of the installer of a plugin is derived from the AppId of the bundle installer
; (with the name of the plugin as suffix) so that each installer has its own uninstall entry.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{844440AC-BE7A-4740-AC5C-EDE795894A63}_{#MyPluginName}
AppName={#MyAppName} {#MyPluginName}
AppVerName={#MyAppName} {#MyPluginName} {#MyPluginVerName}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName="{commonpf64}\Vamp Plugins"
DisableProgramGroupPage=yes
DisableDirPage=no
OutputDir=..\build
InfoBeforeFile={#MyPackageFolder}\About.txt
OutputBaseFilename={#MyPluginName}-install
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[InstallDelete]
; The legacy versions (library + cat files) and the .vamp bundles of the plugin are removed before the installation.
; The plugin can have been installed with its legacy name (e.g. Whisper) or with the ircam-formatted name (e.g. ircamwhisper).
Type: files; Name: "{app}\{#MyPluginName}.dll"
Type: files; Name: "{app}\{#MyPluginName}.cat"
Type: filesandordirs; Name: "{app}\{#MyPluginName}.vamp"
Type: files; Name: "{app}\{#MyPluginAltName}.dll"
Type: files; Name: "{app}\{#MyPluginAltName}.cat"
Type: filesandordirs; Name: "{app}\{#MyPluginAltName}.vamp"
#ifdef MyPluginLegacyModels
; The models of the previous versions of the plugin were installed outside of the Vamp directory.
Type: filesandordirs; Name: "{commonappdata}\Ircam\{#MyPluginLegacyModels}"
#endif

[Files]
#ifdef MyPluginBundleName
; Inno Setup only matches files and wildcards in Source (a directory name alone matches nothing).
Source: "{#MyPackageFolder}\{#MyPluginBundleName}\*"; DestDir: "{app}\{#MyPluginBundleName}"; Flags: recursesubdirs createallsubdirs
#else
Source: "{#MyPackageFolder}\{#MyPluginName}.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyPackageFolder}\{#MyPluginName}.cat"; DestDir: "{app}"; Flags: ignoreversion
#endif
