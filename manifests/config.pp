# == Class vault::config
#
# This class is called from vault for service config.
#
class vault::config {

  $_config_hash = delete_undef_values({
    'backend'           => $::vault::backend,
    'ha_backend'        => $::vault::ha_backend,
    'listener'          => $::vault::listener,
    'telemetry'         => $::vault::telemetry,
    'disable_cache'     => $::vault::disable_cache,
    'default_lease_ttl' => $::vault::default_lease_ttl,
    'max_lease_ttl'     => $::vault::max_lease_ttl,
    'disable_mlock'     => $::vault::disable_mlock,
  })

  $config_hash = merge($_config_hash, $::vault::extra_config)

  file { $::vault::config_dir:
    ensure  => directory,
    purge   => $::vault::purge_config_dir,
    recurse => $::vault::purge_config_dir,
    owner   => $::vault::user,
    group   => $::vault::group,
  }

  file { "${::vault::config_dir}/config.json":
    content => vault_sorted_json($config_hash),
    owner   => $::vault::user,
    group   => $::vault::group,
  }

  # If using the file backend then the path must exist and be readable
  # and writable by the vault user, if we have a file path and the
  # manage_backend_dir attribute is true, then we create it here.
  #
  if $::vault::backend['file'] and $::vault::manage_backend_dir {
    if ! $::vault::backend['file']['path'] {
      fail('Must provide a path attribute to backend file')
    }

    file { $::vault::backend['file']['path']:
      ensure => directory,
      owner  => $::vault::user,
      group  => $::vault::group,
    }
  }

  # If nothing is specified for manage_service_file, defaults will be used
  # depending on the install_method.
  # If a value is passed, it will be interpretted as a boolean.
  if $::vault::manage_service_file == undef {
    case $::vault::install_method {
      'archive': { $real_manage_service_file = true  }
      'repo':    { $real_manage_service_file = false }
      default:   { $real_manage_service_file = false }
    }
  } else {
    validate_bool($::vault::manage_service_file)
    $real_manage_service_file = $::vault::manage_service_file
  }

  if $real_manage_service_file {
    case $::vault::service_provider {
      'upstart': {
        file { '/etc/init/vault.conf':
          ensure  => file,
          mode    => '0444',
          owner   => 'root',
          group   => 'root',
          content => template('vault/vault.upstart.erb'),
        }
        file { '/etc/init.d/vault':
          ensure => link,
          target => '/lib/init/upstart-job',
          owner  => 'root',
          group  => 'root',
          mode   => '0755',
        }
      }
      'systemd': {
        $systemd_version = $::systemd_version
        file { '/etc/systemd/system/vault.service':
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0644',
          content => template('vault/vault.systemd.erb'),
          notify  => Exec['systemd-reload'],
        }
        if ! defined(Exec['systemd-reload']) {
          exec {'systemd-reload':
            command     => 'systemctl daemon-reload',
            path        => '/bin:/usr/bin:/sbin:/usr/sbin',
            user        => 'root',
            refreshonly => true,
          }
        }
      }
      'redhat': {
        file { '/etc/init.d/vault':
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0755',
          content => template('vault/vault.initd.erb'),
        }
      }
      default: {
        fail("vault::service_provider '${::vault::service_provider}' is not valid")
      }
    }
  }
}
