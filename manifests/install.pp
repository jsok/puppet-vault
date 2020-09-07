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

      $_manage_file_capabilities = true
      $_vault_versioned_bin = "/opt/vault-${::vault::version}/vault"

      file { "/opt/vault-${::vault::version}":
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      archive { "${::vault::download_dir}/${::vault::download_filename}":
        ensure       => present,
        extract      => true,
        extract_path => "/opt/vault-${::vault::version}",
        source       => $::vault::real_download_url,
        cleanup      => true,
        creates      => $_vault_versioned_bin,
        before       => File['vault_binary'],
      }

      file { 'vault_binary':
        path   => $vault_bin,
        target => $_vault_versioned_bin,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        notify => Service[$::vault::service_name],
      }

    }

    'repo': {
      package { $::vault::package_name:
        ensure  => $::vault::package_ensure,
      }
      $_manage_file_capabilities = false

      file { 'vault_binary':
        path  => $vault_bin,
        owner => 'root',
        group => 'root',
        mode  => '0755',
      }
    }

    default: {
      fail("Installation method ${::vault::install_method} not supported")
    }
  }

  if !$::vault::disable_mlock and pick($::vault::manage_file_capabilities, $_manage_file_capabilities) {
    file_capability { 'vault_binary_capability':
      ensure     => present,
      file       => pick($_vault_versioned_bin, $vault_bin),
      capability => 'cap_ipc_lock=ep',
      subscribe  => File['vault_binary'],
    }

    if $::vault::install_method == 'repo' {
      Package['vault'] ~> File_capability['vault_binary_capability']
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
