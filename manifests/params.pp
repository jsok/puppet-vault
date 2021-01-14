# == Class vault::params
#
# This class is meant to be called from vault.
# It sets variables according to platform.
#
class vault::params {
  $user               = 'vault'
  $manage_user        = true
  $group              = 'vault'
  $manage_group       = true
  $config_dir         = '/etc/vault'
  $config_mode        = '0750'
  $manage_config_file = true
  $download_url       = undef
  $download_url_base  = 'https://releases.hashicorp.com/vault/'
  $download_extension = 'zip'
  $version            = '1.4.2'
  $service_name       = 'vault'
  $num_procs          = $facts['processorcount']
  $package_name       = 'vault'
  $package_ensure     = 'installed'

  $download_dir        = '/tmp'
  $manage_download_dir = false
  $download_filename   = 'vault.zip'

  # storage and listener are mandatory, we provide some sensible
  # defaults here
  $storage             = { 'file' => { 'path' => '/var/lib/vault' }}
  $manage_storage_dir  = false
  $listener            = {
    'tcp' => {
      'address'     => '127.0.0.1:8200',
      'tls_disable' => 1,
    },
  }

  $enable_ui          = undef

  # These should always be undef as they are optional settings that
  # should not be configured unless explicitly declared.
  $ha_storage         = undef
  $seal               = undef
  $disable_cache      = undef
  $telemetry          = undef
  $default_lease_ttl  = undef
  $max_lease_ttl      = undef
  $disable_mlock      = undef

  $manage_file_capabilities = undef

  $manage_service = true

  $service_enable = true
  $service_ensure = 'running'

  $service_provider = $facts['service_provider']

  case $facts['architecture'] {
    'aarch64':        { $arch = 'arm64' }
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
      $manage_repo         = false
    }
    default: {
      $install_method      = 'archive'
      $bin_dir             = '/usr/local/bin'
      $manage_service_file = undef
      $manage_repo         = true
    }
  }
  $os = downcase($facts['kernel'])
}
