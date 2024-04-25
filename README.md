# Buildroot_for_Buffalo

Tools for building and installing custom firmware on Buffalo devices using tools provided by https://buildroot.org/

To build a firmware image
1. Clone the repository
2. Download the supported buildroot version to the root of the repo
`wget https://buildroot.org/downloads/buildroot-2024.02.1.tar.xz`
3. unpack it
`tar xf buildroot-2024.02.1.tar.xz`
4. Copy the desired configuration into the repository
`cp configs/alpine_defconfig buildroot-2024.02.1/.config`
5. Make any configuration changes desired.
`make menuconfig`
6. Build the project
`make` or `make -j$(nproc)`
7. Refer to the repo wiki pages for details about installing/using the images.


If this project helps you click the Star at the top of the page to let me know! If you'd like to contribute to the continued development/maintenance consider clicking on the sponsor button.

In addition to the Issues and Discussions tabs on GitHub we now also have a Discord channel at https://discord.gg/E88dkcuyW4 or our IRC on Libera.Chat in the #miraheze-buffalonas channel!

If you'd like to help support the project consider donating via the sponsor button above. 
