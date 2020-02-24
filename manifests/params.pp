# == Class vault::params
#
# This class is meant to be called from vault.
# It sets variables according to platform.
#
class vault::params {
  $num_procs          = $facts['processorcount']
  $ip_address         = $facts['networking']['ip']
  $vault_port         = '8200'

  $listener = [
    {
      tcp => {
        address     => "127.0.0.1:${vault_port}",
        tls_disable => true,
      },
    },
    {
      tcp => {
        address     => "${ip_address}:${vault_port}",
        tls_disable => true,
      },
    },
  ]

  $api_addr = "http://${ip_address}:${vault_port}"

  # These should always be undef as they are optional settings that
  # should not be configured unless explicitly declared.
  $default_lease_ttl        = undef
  $disable_cache            = undef
  $disable_mlock            = undef
  $ha_storage               = undef
  $manage_file_capabilities = undef
  $max_lease_ttl            = undef
  $seal                     = undef
  $telemetry                = undef

  $service_provider = $facts['service_provider']

  case $facts['architecture'] {
    /(x86_64|amd64)/: { $arch = 'amd64' }
    'i386':           { $arch = '386'   }
    /^arm.*/:         { $arch = 'arm'   }
    default:          { fail("Unsupported kernel architecture: ${facts['architecture']}") }
  }

  case $facts['os']['family'] {
    'Archlinux': {
      $install_method      = 'repo'
      $bin_dir             = '/bin'
      $manage_service_file = true
    }
    default: {
      $install_method      = 'archive'
      $bin_dir             = '/usr/local/bin'
      $manage_service_file = undef
    }
  }
  $os = downcase($facts['kernel'])
}
