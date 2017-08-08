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
  $bin_dir            = '/usr/local/bin'
  $config_dir         = '/etc/vault'
  $download_url       = undef
  $download_url_base  = 'https://releases.hashicorp.com/vault/'
  $download_extension = 'zip'
  $version            = '0.7.3'
  $service_name       = 'vault'
  $num_procs          = $::processorcount
  $install_method     = 'archive'
  $package_name       = 'vault'
  $package_ensure     = 'installed'

  $download_dir        = '/tmp'
  $manage_download_dir = false
  $download_filename   = 'vault.zip'

  # backend and listener are mandatory, we provide some sensible
  # defaults here
  $backend             = { 'file' => { 'path' => '/var/lib/vault' }}
  $manage_backend_dir  = false
  $listener            = {
    'tcp' => {
      'address'     => '127.0.0.1:8200',
      'tls_disable' => 1,
    },
  }

  # These should always be undef as they are optional settings that
  # should not be configured unless explicitly declared.
  $ha_backend         = undef
  $disable_cache      = undef
  $telemetry          = undef
  $default_lease_ttl  = undef
  $max_lease_ttl      = undef
  $disable_mlock      = undef

  $manage_service = true
  $manage_proxy = false
  $proxy_address = undef
  $manage_service_file = undef

  case $::osfamily {
    'Debian': {
      case $::lsbdistcodename {
        /(jessie|stretch|sid|xenial|yakketi|zesty)/: {
          $service_provider = 'systemd'
        }
        /(trusty|vivid)/: {
          $service_provider = 'upstart'
        }
        default: {
          $service_provider = 'systemd'
          warning("Module ${module_name} is not supported on '${::lsbdistcodename}'")
        }
      }
    }
    'RedHat': {
      if ($::operatingsystemmajrelease == '6' or $::operatingsystem == 'Amazon') {
        $service_provider = 'redhat'
      } else {
        $service_provider = 'systemd'
      }
    }
    default: {
      fail("Module ${module_name} is not supported on osfamily '${::osfamily}'")
    }
  }
  case $::architecture {
    'x86_64', 'amd64': { $arch = 'amd64' }
    'i386':            { $arch = '386'   }
    /^arm.*/:          { $arch = 'arm'   }
    default:           {
      fail("Unsupported kernel architecture: ${::architecture}")
    }
  }
  $os = downcase($::kernel)
}
