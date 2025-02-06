# Buildroot_for_Buffalo

Tools for building and installing custom firmware on Buffalo devices using tools provided by https://buildroot.org/

## Summary
Configuration files and scripts to generate custom Linux images for Buffalo devices based on Buildroot. 

These images have some advantages over a more traditional distro like Debian, including:
* All software custom compiled for the target device. This results in smaller, better-optimized binaries in most cases.
* Much smaller OS images compared to even a minimal Debian install.
* Can be built around kernels/etc that would otherwise be incompatible with Debian/etc


## To build a firmware image
1. Clone the repository

`git clone https://github.com/1000001101000/Buildroot_for_Buffalo`

2. Switch to the repo directory

`cd Buildroot_for_Buffalo`

2. Download the supported buildroot version to the root of the repo

`wget https://buildroot.org/downloads/buildroot-2024.11.1.tar.xz`

4. unpack it

`tar xf buildroot-2024.11.1.tar.xz`

5. Copy the desired configuration into the buildroot directory.

`cp configs/alpine_defconfig buildroot-2024.11.1/.config`

6. Enter the buildroot directory

`cd buildroot-2024.11.1/`

6. Make any configuration changes desired.

`make menuconfig`

7. Build the project

`make`

8. Refer to the repo wiki pages for details about installing/using the images.


If this project helps you click the Star at the top of the page to let me know! If you'd like to contribute to the continued development/maintenance consider clicking on the sponsor button.

In addition to the Issues and Discussions tabs on GitHub we now also have a Discord channel at https://discord.gg/E88dkcuyW4 or our IRC on Libera.Chat in the #miraheze-buffalonas channel!

If you'd like to help support the project consider donating via the sponsor button above. 
