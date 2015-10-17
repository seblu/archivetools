# Maintainer: Sébastien Luttringer

pkgname=archivetools-git
pkgver="$(git log --pretty=format:''|wc -l)"
pkgrel=1
pkgdesc='Archlinux Archive Tools (Git version)'
arch=('any')
url='https://github.com/seblu/archivetools'
license=('GPL2')
depends=('rsync' 'hardlink' 'xz' 'util-linux')
conflicts=('archivetools')
backup=('etc/archive.conf')
install=archivetools.install

package() {
  cd "$startdir"
  install -Dm644 archive.conf "$pkgdir/etc/archive.conf"
  install -Dm755 archive.sh "$pkgdir/usr/bin/archive"
  # systemd stuff
  install -Dm644 archive.sysusers "$pkgdir/usr/lib/sysusers.d/archive.conf"
  install -Dm644 archive.tmpfiles "$pkgdir/usr/lib/tmpfiles.d/archive.conf"
  for _p in archive.{timer,service} archive-hardlink.{timer,service}; do
    install -Dm644 $_p "$pkgdir/usr/lib/systemd/system/$_p"
  done
}

# vim:set ts=2 sw=2 et:
