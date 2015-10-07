# Definition: adapter::st2_uwsgi_init
#
#  This adapter creates an init script calling UWSGI for
#  a given StackStorm subsystem. This is to disable the
#  default standalone server started by st2ctl, but to
#  keep that script still usable.
#
define adapter::st2_uwsgi_init (
  $subsystem = $name,
) {
  if ! defined(Class['uwsgi']) and ! defined(Class['::st2::profile::server']) {
    fail("[Adapter::St2_uwsgi_init[${name}]: This adapter can only be used in conjunction with 'uwsgi' and 'st2::profile::server")
  }

  if $::initsystem != 'upstart' or $::initsystem != 'systemd' {
    fail("[Adapter::St2_uwsgi_init[${name}]: This adapter only supports systemd and upstart init systems, currently")
  }

  $_subsystem_map = {
    'api'          => 'st2api',
    'st2api'       => 'st2api',
    'auth'         => 'st2auth',
    'st2auth'      => 'st2auth',
    'installer'    => 'st2installer',
    'st2installer' => 'st2installer',
    'mistral'      => 'mistral-api',
  }
  $_subsystem = $_subsystem_map[$subsystem]

  if $::initsystem == 'upstart' {
    $_init_file = "/etc/init/${_subsystem}.conf"
    $_template = $_subsystem ? {
      'mistral-api' => 'anchor.conf.erb',
      default       => 'init.conf.erb',
    }
  } elsif $::initsystem == 'systemd' {
    $_init_file = "/etc/systemd/system/${_subsystem}.service"
    $_template = $_subsystem ? {
      'mistral-api' => 'anchor.service.erb',
      default       => 'init.service.erb',
    }
  }

  file { $_init_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template("adapter/st2_uwsgi_init/${_template}"),
    notify  => Service[$_subsystem],
  }

  service { $_subsystem:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Class['st2::profile::server'],
  }

  # Subscribe to Uwsgi Apps of the same name.
  File["/etc/uwsgi.d/${_subsystem}.ini"] ~> Service[$_subsystem]
}
