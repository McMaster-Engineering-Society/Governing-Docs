## Install Latex on WSL
1. Do not install with `sudo apt install texlive` or anything of that sort. This will give older versions of tex that may give issues with other custom downloaded packages.
2. From [tug instructions](https://www.tug.org/texlive/quickinstall.html), use the following steps:
```
wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
tar -xhf install-tl-unx.tar.gz
cd install-tl-unx
sudo perl ./install-tl --no-interaction
```

## Add Latex to PATH
1. Go to home directory, `cd ~`
2. Edit the `.bashrc` file, `code .bashrc`
3. Add the following line to the end of the file.
- `export PATH="$PATH:/usr/local/texlive/2024/bin/x86_64-linux"`
4. Refresh the shell's environment with `. ~/.bashrc`

## Environment Setup
1. Install the following VS Code Extensions
- `LaTeX Utilities`
- `Latex Workshop`
2. Copy the contents of `settings.json` to `~/.vscode-server/settings.json`
3. Install the Arial font that is used
- `sudo apt install ttf-mscorefonts-installer` and agree to the terms
4. Install some modules to be able to run the formatter
- `sudo apt-get install libyaml-tiny-perl libfile-homedir-perl`

##
