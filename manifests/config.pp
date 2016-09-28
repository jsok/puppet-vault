# == Class vault::config
#
# This class is called from vault for service config.
#
class vault::config {


  $config_hash = delete_undef_values({
    'backend'           => $::vault::backend,
    'ha_backend'        => $::vault::ha_backend,
    'listener'          => $::vault::listener,
    'telemetry'         => $::vault::telemetry,
    'disable_cache'     => $::vault::disable_cache,
    'default_lease_ttl' => $::vault::default_lease_ttl,
    'max_lease_ttl'     => $::vault::max_lease_ttl,
    'disable_mlock'     => $::vault::disable_mlock,
  })


  file { $::vault::config_dir:
    ensure  => directory,
    purge   => $::vault::purge_config_dir,
    recurse => $::vault::purge_config_dir,
  } 

  file { "${::vault::config_dir}/config.json":
    content => vault_sorted_json($config_hash),
    owner   => $::vault::user,
    group   => $::vault::group,
  }

  if $::vault::install_method == 'archive' {
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
