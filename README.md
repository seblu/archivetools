Archive Tools
=============

Introduction
------------
**archivetools** is a collection of tool used to setup an [Archlinux Archive](https://wiki.archlinux.org/index.php/Arch_Linux_Archive).

It's a turnkey solution to backups Archlinux repositories.

Installation
------------
Create a pacman package and install it.

```
cd archivetools
makepkg -i
systemctl enable archive.timer archive-hardlink.timer
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
**archivetools** was started by *Sébastien Luttringer* in August 2013 to replace the former *Archlinux Rollback Machine* service.