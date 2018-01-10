# == Class vault::install
#
class vault::install {
  $vault_bin = "${::vault::bin_dir}/vault"

  case $::vault::install_method {
      'archive': {
        if $::vault::manage_download_dir {
          file { $::vault::download_dir:
            ensure => directory,
          }
        }

        archive { "${::vault::download_dir}/${::vault::download_filename}":
          ensure       => present,
          extract      => true,
          extract_path => $::vault::bin_dir,
          source       => $::vault::real_download_url,
          cleanup      => true,
          creates      => $vault_bin,
          before       => File[$vault_bin],
        }
      }

    'repo': {
      package { $::vault::package_name:
        ensure  => $::vault::package_ensure,
      }
    }

    default: {
      fail("Installation method ${::vault::install_method} not supported")
    }
  }

  file { $vault_bin:
    owner => 'root',
    group => 'root',
    mode  => '0755',
  }

  if !$::vault::disable_mlock {
    exec { "setcap cap_ipc_lock=+ep ${vault_bin}":
      path        => ['/sbin', '/usr/sbin', '/bin', '/usr/bin', ],
      subscribe   => File[$vault_bin],
      unless      => "getcap ${vault_bin} | grep cap_ipc_lock+ep",
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
