Arch Linux Archive Tools
========================

Introduction
------------
**archivetools** is the project used to run the [Arch Linux Archive](https://wiki.archlinux.org/index.php/Arch_Linux_Archive). It's a turnkey solution to snapshot [Arch Linux](https://www.archlinux.org) packages repositories, ISOs images and boostrap tarballs. You can deploy one for your own needs.

The **Archive** is built by rsync'ing [rsync.archlinux.org](rsync://rsync.archlinux.org), or its mirrors, each day. *Rsync* features are used to transfer only the diff of new data from the previous snapshot and files are stored once with use of hardlinks.

Installation
------------
Create a pacman package and install it.

```
cd archivetools
makepkg -i
systemctl enable archive.timer
```

Debug
-----
```
cd archivetools
export DEBUG=1
export ARCHIVE_CONFIG=archive.conf.test
./archive.sh
```

Dependencies
------------
- [Bash](http://www.gnu.org/software/bash/bash.html)
- [Rsync](http://rsync.samba.org/)
- [Hardlink](http://jak-linux.org/projects/hardlink/)
- [xz](http://tukaani.org/xz/)
- [util-linux](https://www.kernel.org/pub/linux/utils/util-linux/)

Sources
-------
**archivetools** sources are available on [github](https://github.com/seblu/archivetools/).

License
-------
**archivetools** is licensied under the term of [GPL v2](http://www.gnu.org/licenses/gpl-2.0.html).

Author
------
**archivetools** was started by *Sébastien Luttringer* in August 2013 to replace the former *Arch Linux Rollback Machine* service.
