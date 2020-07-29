# == Class vault::install
#
class vault::install {
  $vault_bin = "${vault::install_dir}/bin/vault"

  file { $vault::install_dir:
    ensure => directory,
    owner  => $vault::user,
    group  => $vault::group,
    mode   => $vault::config_mode,
  }

  ~> file { "${vault::install_dir}/bin":
    ensure => directory,
    owner  => $vault::user,
    group  => $vault::group,
    mode   => $vault::config_mode,
  }

  ~> file { "${vault::install_dir}/certs":
    ensure => directory,
    owner  => $vault::user,
    group  => $vault::group,
    mode   => $vault::config_mode,
  }

  case $vault::install_method {
      'archive': {
        if $vault::manage_download_dir {
          file { $vault::download_dir:
            ensure => directory,
          }
        }

        archive { "${vault::download_dir}/${vault::download_filename}":
          ensure       => present,
          extract      => true,
          extract_path => "${vault::install_dir}/bin",
          source       => $vault::real_download_url,
          cleanup      => true,
          creates      => $vault_bin,
          before       => File['vault_binary'],
        }

        $_manage_file_capabilities = true
      }

    'repo': {
      package { $vault::package_name:
        ensure  => $vault::package_ensure,
      }
      $_manage_file_capabilities = false
    }

    default: {
      fail("Installation method ${vault::install_method} not supported")
    }
  }

  file { 'vault_binary':
    path  =>  $vault_bin,
    owner => 'root',
    group => 'root',
    mode  => '0755',
  }

  file { 'vault_binary_link':
    ensure => link,
    path   => "${vault::bin_dir}/vault",
    target => $vault_bin,
  }

  if !$vault::disable_mlock and pick($vault::manage_file_capabilities, $_manage_file_capabilities) {
    file_capability { 'vault_binary_capability':
      ensure     => present,
      file       => $vault_bin,
      capability => 'cap_ipc_lock=ep',
      subscribe  => File['vault_binary'],
    }

    if $vault::install_method == 'repo' {
      Package['vault'] ~> File_capability['vault_binary_capability']
    }
  }

  if $vault::manage_user {
    user { $vault::user:
      ensure => present,
    }
    if $vault::manage_group {
      Group[$vault::group] -> User[$vault::user]
    }
  }
  if $vault::manage_group {
    group { $vault::group:
      ensure => present,
    }
  }
}
