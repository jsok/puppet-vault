# == Class vault::install
#
class vault::install {
  $vault_bin = "${::vault::bin_dir}/vault"

  case $::vault::install_method {
    'archive': {
      staging::deploy { 'vault.zip':
        source  => $::vault::download_url,
        target  => $::vault::bin_dir,
        creates => $vault_bin,
        notify  => File[$vault_bin]
      }
    }

    'repo': {
      package { $::vault::package_name:
        ensure  => $::vault::package_ensure
      }
    }

    default: {
      fail("Installation method ${::vault::install_method} not supported")
    }
  }

  file { $vault_bin:
    owner => 'root',
    group => 'root',
    mode  => '0555',
  }

  if !$::vault::config_hash['disable_mlock'] {
    exec { "setcap cap_ipc_lock=+ep ${vault_bin}":
      path        => ['/sbin', '/usr/sbin'],
      subscribe   => File[$vault_bin],
      refreshonly => true,
    }
  }

  if $vault::manage_user {
    user { $::vault::user:
      ensure => present,
    }
    if $vault::manage_group {
      Group[$vault::group] -> User[$vault::user]
    }
  }
  if $vault::manage_group {
    group { $::vault::group:
      ensure => present,
    }
  }

}
