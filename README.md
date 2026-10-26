# Partiels Vamp Plugins

The repository that packages and distributes the Vamp plugins developed at Ircam for [Partiels](https://github.com/Ircam-Partiels/Partiels).

For Windows, MacOS and Linux, the continuous integration downloads the binaries and the bundles of the plugins, generates the installers (with the possibility to select the plugins at the installation), signs and notarizes the MacOS installers, publishes them as artifacts and publishes them in the GitHub releases when a tag is pushed. Each release also generates the `Partiels-Plugins.json` plugin list that automates the update of the plugins in the plugin manager of Partiels.

## The plugins

The properties of the plugins are defined in the [resource/plugins.json](resource/plugins.json) file:

| Field | Description |
| --- | --- |
| `identifier` | The identifier of the plugin library used by the plugin manager of Partiels (e.g. `supervp`). |
| `name` | The name of the plugin (e.g. `SuperVP`). |
| `maker` | The maker of the plugin (e.g. `Ircam`). |
| `gitlabId` | The project id on the [Ircam Forge 2](https://forge-2.ircam.fr), if the plugin is hosted there. The binaries are retrieved from the `Build::Windows`, `Build::MacOS` and `Build::Linux` artifacts of the given ref (a branch or a tag). |
| `repository` | The GitHub repository of the plugin (e.g. `Ircam-Partiels/whisper-vamp-plugin`), if the plugin is hosted there. The bundle of the plugin is retrieved from the `<name>-Vamp-<os>.zip` asset of the given release (the ref is a release tag, or `latest` to use the most recent one). |
| `ref` | The branch or the tag of the plugin. |
| `description` | The description of the plugin library (used in the About file of the installers and by the plugin manager of Partiels). |
| `features` | The features of the plugin, as a list (e.g. `["Beat Detection", "Mean Tempo Estimate"]`) — the outputs displayed by the plugin manager of Partiels. |
| `minOs` | The minimum MacOS version of the plugin (used to propose the plugin in the MacOS installer). |
| `architectures` | The architectures supported by the plugin (the plugins that do not support `x86_64` are only proposed on the Apple Silicon machines). |
| `manuals` | `true` if the plugin has a manual (retrieved from the `Doc` artifact on the Ircam Forge 2). |
| `legacyModels` | The name of the directory where the previous versions of the plugin installed their models outside of the Vamp directory (e.g. `vaxmodels`), if any. The directory (in `~/.config/Ircam` on Linux, `/Library/Application Support/Ircam` on MacOS and `C:\ProgramData\Ircam` on Windows) is removed at the installation and at the uninstallation of the plugin. |

The ref of a plugin can be overridden on the command line (e.g. `-DSUPERVP_REF=7.0.1`).

## The packages

The generation of the packages is based on [CMake](https://cmake.org) in script mode (see [generate-packages.cmake](generate-packages.cmake)) and on the native packaging tools of each operating system:

- **MacOS**: the plugins are installed in `/Library/Audio/Plug-Ins/Vamp`. Each plugin is packaged with `pkgbuild` (with a `preinstall` script that removes the previous versions) and the bundle installer is generated with `productbuild` (the plugins can be selected at the installation, the plugins that are not compatible with the machine or the operating system are not proposed). The binaries are signed with the `Developer ID Application` certificate and the installers are signed with the `Developer ID Installer` certificate, notarized with `notarytool`, stapled and verified with `spctl`.
- **Windows**: the plugins are installed in `C:\Program Files\Vamp Plugins`. The installers are generated with [Inno Setup](https://jrsoftware.org/isinfo.php) (with a component per plugin, which allows the selection at the installation); each installer is uninstallable from the Windows settings (the installers of the plugins have their own uninstall entry derived from the bundle installer).
- **Linux**: the plugins are installed in `$HOME/vamp`. The package is a directory with an `Install.sh` script (the plugins can be selected with the arguments of the script, with the option `--all`, or interactively) and one standalone installation directory per plugin; an `Uninstall.sh` script (with the same selection options) is also provided in the package and in the standalone directories of the plugins.

One installer per plugin is also generated (this can be disabled with the option `PVP_GENERATE_PLUGIN_INSTALLERS=OFF`). The manuals of the plugins are retrieved with the option `PVP_GENERATE_MANUALS=ON`.

## The continuous integration

The continuous integration is based on [GitHub Actions](https://github.com/features/actions) (see [.github/workflows/main.yml](.github/workflows/main.yml)). It is organized as one job per kind of package (like the [Partiels](https://github.com/Ircam-Partiels/Partiels) repository); each job generates the packages of its kind, prepares the assets of the release and publishes them in the GitHub releases when a tag is pushed:

- The **MacOS** job runs on `macos-latest` (Apple Silicon, required by several plugins): it generates the packages, signs and notarizes them (if the certificates are available) and publishes the bundle installer, the installer of each plugin and the uninstallation script.
- The **Windows** job runs on `windows-latest`: it generates the bundle installer and the installer of each plugin.
- The **Linux** job runs on `ubuntu-latest`: it generates the bundle installer and the installer of each plugin.
- The **Doc** job runs on `ubuntu-latest`: it retrieves the manuals of the plugins and generates the plugin list (`Partiels-Plugins.json`) that automates the update of the plugins in the plugin manager of Partiels.

| Asset | Content |
| --- | --- |
| `Uninstall-MacOS.sh` | The uninstallation script of MacOS (run it with sudo). |
| `<name>-MacOS.pkg` | The installer of a single plugin on MacOS (e.g. `SuperVP-MacOS.pkg`). |
| `<name>-Windows.exe` | The installer of a single plugin on Windows (e.g. `SuperVP-Windows.exe`). |
| `<name>-Linux.zip` | The installer of a single plugin on Linux (e.g. `SuperVP-Linux.zip`). |
| `Partiels-Vamp-Plugins-Manuals.zip` | The manuals of the plugins. |
| `Partiels-Plugins.json` | The plugin list used by the plugin manager of Partiels. |

The names of the per-plugin installers follow the `<name>-<os>` convention used by the Whisper, Crepe and IPT plugin repositories. Each job publishes one artifact (`Partiels-Vamp-Plugins-<os>` or `Partiels-Vamp-Plugins-Doc`) that contains all the packages and installers of its kind at its root (the downloaded artifacts are zipped automatically by GitHub). The bundle installers (that install all the plugins) are published as artifacts and not as release assets: GitHub limits the size of the release assets to 2 GB and the bundle installers are bigger because they contain the models of all the plugins.

### The secrets

The secrets are the same as the ones used by the [Whisper](https://github.com/Ircam-Partiels/whisper-vamp-plugin), [Crepe](https://github.com/Ircam-Partiels/crepe-vamp-plugin) and [IPT](https://github.com/Ircam-Partiels/ipt-vamp-plugin) plugin repositories (there is no code signing on Windows).

| Secret | Description |
| --- | --- |
| `FORGE_PRIVATE_TOKEN` | The private token of the Ircam Forge 2 (required to download the artifacts of the plugins hosted on the forge). |
| `DEV_ID_APP_CERT` | The `Developer ID Application` certificate, in a base64 encoded `.p12` file. |
| `DEV_ID_INST_CERT` | The `Developer ID Installer` certificate, in a base64 encoded `.p12` file. |
| `DEV_ID_PASSWORD` | The password of the `.p12` files (also used to protect the temporary keychain). |
| `DEV_USER_APPLE_ID` | The Apple ID used for the notarization. |
| `DEV_TEAM_APPLE_ID` | The team ID used for the notarization. |
| `DEV_SPEC_APP_PASSWORD` | The app-specific password used for the notarization. |

### The speed of the continuous integration

The downloaded plugins (more than 1.5 GB per operating system with the models of the deep learning plugins) are cached with the `actions/cache` action: the zip files downloaded from the Ircam Forge 2 and GitHub are stored in the `plugins-cache` directory and the cache key is derived from the `resource/plugins.json` file (the plugins are only downloaded again when the file has changed). The manuals, retrieved from the `Doc` artifacts of the forge, share the same cache. The main cost that remains is the notarization of the MacOS packages: each installer is submitted to the Apple service (which takes around one minute per installer).

### The release

The release system is based on the creation of tags in git:

```sh
git tag -a 1.0.0 -m "Version 1.0.0 of the Partiels Vamp Plugins"
git push origin 1.0.0
```

The plugin list `Partiels-Plugins.json` is generated by [generate-plugin-list.cmake](generate-plugin-list.cmake) from the metadata of the resource/plugins.json file and from the per-plugin installers of the release. Each entry also describes the compatibility of the MacOS package with the `minVersionMacos` (the `minOs` property) and `architecturesMacos` (the `architectures` property) fields. The plugin list of a given version of Partiels can be updated by copying the file in the `BinaryData/Resource` directory of the Partiels source.

## Local generation

The MacOS and Windows packages must be generated on their respective operating systems. The Linux and manuals packages can be generated on any operating system using the options `PVP_GENERATE_LINUX` and `PVP_GENERATE_MANUALS`:

```sh
git clone https://github.com/Ircam-Partiels/Partiels-Vamp-Plugins.git
cd Partiels-Vamp-Plugins
mkdir build && cd build
cmake -D PRIVATE_TOKEN=<token> -D PVP_BUILD_TAG="1.0.0" -P ../generate-packages.cmake
```

The private token of the Ircam Forge 2 can also be defined with the `FORGE_PRIVATE_TOKEN` environment variable (used by the continuous integration) or retrieved from the keychain on MacOS (the `Forge2 Ircam Token` password). The installers are collected in the `package` directory of the repository. The downloaded plugins can be cached between the generations with the option `PVP_CACHE_DIRECTORY` (used by the continuous integration with the `plugins-cache` directory).

### Credits

This project is designed and developed by Pierre Guillot at [IRCAM](https://www.ircam.fr/) IMR.
The plugins rely on models and libraries developed by their respective authors:
- SuperVP and Pm2: engine by Axel Roebel and Frédéric Cornu, based on an initial version by Philippe Depalle.
- IrcamBeat and IrcamDescriptor: libraries by Geoffroy Peeters and Frédéric Cornu.
- Fcn: deep learning models by Luc Ardaillon and Axel Roebel.
- VAX: library by Guillaume Doras, Yann Teytaut and Axel Roebel.
- Crepe: CREPE model by Jong Wook Kim, Justin Salamon, Peter Li and Juan Pablo Bello.
- IPT: deep learning CNN models by Nicolas Brochec, Joakim Borg and Marco Fiorini.
- Whisper: Whisper models by OpenAI.
