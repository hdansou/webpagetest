packages:
  pkg.installed:
    - pkgs: {{ pillar['webpagetest']['packages'] }}

ffmpeg:
  pkgrepo.managed:
    - ppa: jon-severinsson/ffmpeg
  pkg.installed:
    - name: ffmpeg
    - refresh: True

httpservices:
  pkg.installed:
    - pkgs:
      - {{ pillar['webpagetest']['http'] }}
      - {{ pillar['webpagetest']['php'] }}

/var/www/vhosts/{{ pillar['webpagetest']['sitename'] }}:
  archive.extracted:
    - source: {{ pillar['webpagetest']['zipurl'] }}
    - source_hash: {{ pillar['webpagetest']['zipsha'] }}
    - archive_format: zip
    - if_missing: /var/www/vhosts/{{ pillar['webpagetest']['sitename'] }}/www

/var/www/vhosts/{{ pillar['webpagetest']['sitename'] }}/www:
  file.directory:
    - user: www-data
    - group: www-data
    - file_mode: 644
    - dir_mode: 755
    - recurse:
      - user
      - group
      - mode
    - require_in:
      - mount: mount-tmpfs

/etc/cron.daily/wptupdate:
  file.managed:
    - source: salt://webpagetest/files/wptupdate.cron
    - template: jinja
    - user: root
    - group: root
    - mode: 755

include:
  - webpagetest.{{ pillar['webpagetest']['http'] }}

mount-tmpfs:
  mount.mounted:
    - name: /var/www/vhosts/{{ pillar['webpagetest']['sitename'] }}/www/tmp
    - device: tmpfs
    - fstype: tmpfs
    - mkmnt: True
    - opts:
      - size=256m

/var/www/vhosts/{{ pillar['webpagetest']['sitename'] }}/www/settings/settings.ini:
  file.managed:
    - source: salt://webpagetest/files/settings.ini
    - template: jinja

/var/www/vhosts/{{ pillar['webpagetest']['sitename'] }}/www/settings/locations.ini:
  file.managed:
    - source: salt://webpagetest/files/locations.ini
    - template: jinja

/var/www/vhosts/{{ pillar['webpagetest']['sitename'] }}/www/settings/feeds.inc:
  file.managed:
    - source: salt://webpagetest/files/feeds.inc
    - template: jinja
