# == Class vault::config
#
# This class is called from vault for service config.
#
class vault::config {
  file { $::vault::config_dir:
    ensure  => directory,
    purge   => $::vault::purge_config_dir,
    recurse => $::vault::purge_config_dir,
  } ->
  file { "${::vault::config_dir}/config.json":
    content => vault_sorted_json($::vault::config_hash),
  }

  file { '/etc/init/vault.conf':
    mode    => '0444',
    owner   => 'root',
    group   => 'root',
    content => template('vault/vault.upstart.erb'),
  }

  case $operatingsystem {
    'RedHat', 'CentOS': {
      file { '/etc/init.d/vault':
        mode    => '0555',
        owner   => 'root',
        group   => 'root',
        content => template('vault/vault.init.erb'),
      }
    }
    /^(Debian|Ubuntu)$/:{
      file { '/etc/init.d/vault':
        ensure  => link,
        target  => '/lib/init/upstart-job',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
      }
    }
  }
}
