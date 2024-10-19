
##heimdal/samba crossbuild issue waiting to be merged
curl "https://patchwork.ozlabs.org/project/buildroot/patch/20240210103634.3502847-1-bernd@kuhls.net/raw/" 2>/dev/null | patch -N -p1

##patch to add sysbench and dependency may need to look into why never merged
curl "https://marc.info/?l=buildroot&m=170021431900448&q=raw" 2>/dev/null | patch -N -p1
curl "https://marc.info/?l=buildroot&m=170021430500441&q=raw" 2>/dev/null | patch -N -p1

#BR2_PACKAGE_CK_ARCH_SUPPORTS=y
#BR2_PACKAGE_CK=y
#BR2_PACKAGE_SYSBENCH_ARCH_SUPPORTS=y
#BR2_PACKAGE_SYSBENCH=y

##procps-ng regression already fixed in main
curl https://github.com/buildroot/buildroot/commit/3b870057c646a6b7abc822d3ce2ea0f41683420b.patch 2>/dev/null | patch -N -p1

##sometime between commit dc172396fb60fc207776573563fe458bdbd2cc63 and present the atspool directory became necessary for jobs to actually run.
##Mar 28 02:06:03 buildroot cron.err atd[1584]: Cannot chdir to /var/spool/cron/atspool: No such file or directory
patch -N -p1 << EOF
diff --git a/package/at/S99at b/package/at/S99at
index f132a46..1faf741 100644
--- a/package/at/S99at
+++ b/package/at/S99at
@@ -11,6 +11,7 @@ start() {
	# Check if not exists otherwise create it
	if [ ! -f /var/spool/cron/atjobs/.SEQ ]; then
		mkdir -p /var/spool/cron/atjobs/
+		mkdir -p /var/spool/cron/atspool/
		touch /var/spool/cron/atjobs/.SEQ
		printf "atd: created missing .SEQ file (atjobs will be lost on reboot)\n"
	fi
EOF

patch -N -p1 < ../patches/buildroot_zfs_initscripts.patch

exit 0
