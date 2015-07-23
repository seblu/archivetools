#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
archarchive.cli
---------------

Main `archarchive.cli` CLI.
"""
import click
import contextlib
import logging
import os

from datetime import datetime

# commands
from sh import wget


log = logging.getLogger('archarchive')


@contextlib.contextmanager
def cd(path):
    old_path = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(old_path)


def iso_sync(iso_sync_url, dest, period):
    log.debug('iso_sync(iso_sync_url: {0}, dest: {1})'.format(iso_sync_url, dest))

    # build the full upstream url with the root parent url and the current month
    upstream_url = "{0}/{1}/".format(iso_sync_url, period)
    log.debug('upstream_url: {0}'.format(upstream_url))
    log.debug('dest: {0}'.format(dest))

    def dump_err(line):
        log.debug(line)

    with cd(dest):
        log.debug('wget -e robots=off --reject "index.html*" --mirror --no-host-directories --cut-dirs=2 --no-parent {0}'.format(upstream_url))
        output = wget('-nv', '-e robots=off', '--reject', '"index.html*"',
                      '--mirror', '--no-host-directories', '--cut-dirs=2',
                      '--no-parent', '{0}'.format(upstream_url),  _err=dump_err)

        log.debug(output)


def repo_sync(pkg_sync_url, dest, date):
    log.debug('repo_sync(pkg_sync_url: {0}, date: {1})'.format(pkg_sync_url, date))

    target = '{0}/'.format(os.path.join(dest, date))
    log.debug('target: {0}'.format(target))

    log.debug('Finding last sync')
    versions = [path for path in os.listdir(dest) if os.path.isdir(os.path.join(dest, path)) and not date == path]
    versions.sort()
    latest = versions[-1]
    log.debug('latest: {0}'.format(latest))

    source = '{0}/'.format(os.path.join(dest, latest))
    log.debug('source to sync against: {0}'.format(source))

    def dump_out(line):
        log.debug(line)

    cmd = "rsync -rltvH "+ \
          "--link-dest={0} ".format(source)+ \
          "--exclude '*/.*' --exclude '*/os/i686' " + \
          "--exclude 'pool/*/*-i686.pkg.*' {0} {1}".format(pkg_sync_url, target)

    log.debug(cmd)
    os.system(cmd)


def link_update(link_dir, version):
    log.debug('link_update(link_dir: {0}, version: {1})'.format(link_dir, version))

    current_link_tgt = os.path.join(link_dir, 'current')
    week_link_tgt = os.path.join(link_dir, 'week')
    month_link_tgt = os.path.join(link_dir, 'month')
    version_link_tgt = os.path.join(link_dir, version)

    link_tgts = [current_link_tgt,
                 week_link_tgt,
                 month_link_tgt,
                 version_link_tgt]

    version_link_src = os.path.join(link_dir, version)
    log.debug('version_link_src: {0}'.format(version_link_src))

    for link_tgt in link_tgts:
        log.debug('link_tgt: {0}'.format(link_tgt))
        if os.path.lexists(link_tgt):
            if os.path.islink(link_tgt):
                existing_link_src = os.readlink(link_tgt)
                log.debug('existing_link_src: {0}'.format(existing_link_src))

                if existing_link_src != version_link_src:
                    log.debug('version has changed, relinking to: {0}'.version_link_src)

                    log.debug('rm {0}'.format(link_tgt))
                    os.remove(link_tgt)
                else:
                    log.debug('version has not changed, leaving as is: {0}'.format(version_link_src))
            else:
                log.debug('we dont have a symlink, something is wrong: {0}'.format(link_tgt))

        else:
            log.debug('version is new: {0}'.format(version_link_src))

            log.debug('ln -s {0} {1}'.format(version_link_src, link_tgt))
            os.symlink(version_link_src, link_tgt)

        log.debug('-------')


@click.command()
@click.option('--pkg-sync-url', default="rsync://mirror.pkgbuild.com/packages/", show_default=True)
@click.option('--iso-sync-url', default="http://mirrors.kernel.org/archlinux/iso", show_default=True)
@click.option('--run-dir', default="/var/run/", show_default=True)
@click.option('--data-dir', default='/srv/data/mirror/archlinux', show_default=True)
@click.option('--version', default=datetime.now().strftime('%Y.%m.%d'), show_default=True)
@click.option('--debug', is_flag=True, show_default=True)
@click.option('--no-iso-sync', is_flag=True, show_default=True)
@click.option('--no-repo-sync', is_flag=True, show_default=True)
def sync(pkg_sync_url, iso_sync_url, run_dir, data_dir, version, debug, no_iso_sync, no_repo_sync):
    click.echo("sync: pkg_sync_url: %s, iso_sync_url: %s, run_dir: %s, data_dir: %s" % (pkg_sync_url, iso_sync_url, run_dir, data_dir))

    if debug:
        logging.basicConfig(level=logging.DEBUG)
        logging.getLogger('sh').setLevel(logging.WARN)
    else:
        logging.basicConfig(level=logging.INFO)

    if not no_iso_sync:
        iso_version = datetime.now().strftime('%Y.%m.01')
        iso_sync(iso_sync_url, '{0}/archive/iso'.format(data_dir), iso_version)
        link_update('{0}/archive/iso'.format(data_dir), iso_version)

    if not no_repo_sync:
        repo_sync(pkg_sync_url, '{0}/archive/repo'.format(data_dir), version)
        link_update('{0}/archive/repo'.format(data_dir), version)
