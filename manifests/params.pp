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
  $version            = '0.7.0'
  $service_name       = 'vault'
  $num_procs          = $::processorcount
  $install_method     = 'archive'
  $package_name       = 'vault'
  $package_ensure     = 'installed'

  $checksum_type       = 'sha256'
  $checksums           = {
    'darwin_386'    => '11d60c33e45ec842876ff7828eb1adf2abe97d1e845f92d7234013171d3a977e',
    'darwin_amd64'  => 'db995adf0e46dd7ae43d2fa3523f44a007a6adc37c3a47de5c667a1361cffc13',
    'freebsd_386'   => 'd215da31431b91e5563152566f818a40df6ee2d07e2a43f5e2561edd95631caf',
    'freebsd_amd64' => 'c0ee3541cc53b6d1502e2629f24cec64ce5b07b4f867c648755fbdb26075a3b2',
    'freebsd_arm'   => 'e74972a2136487e70cb224303ee8a9daebc71162b1b2f1b1dca36489a6105fc0',
    'linux_386'     => 'b4bcf45ca5fa006a4d7f8e226e0483201c71ee2b7fb01c73db116a4fe6c29c9f',
    'linux_amd64'   => 'c6d97220e75335f75bd6f603bb23f1f16fe8e2a9d850ba59599b1a0e4d067aaa',
    'linux_arm'     => '0809126db9951c5b31aadf4c538889dc720d398d7f05278f50d794137edb95a9',
    'netbsd_386'    => '82f5df0e9c70c1921d9a2c65f47b40eb65f9879ee21ab2f0b7cb7d41d1045101',
    'netbsd_amd64'  => '28d9e448c7e9d44ab81695ed7ad6482db09e6d22553e0fa0e49c70f71abeb72a',
    'netbsd_arm'    => 'e280caa50e51443ad6b6a5d445a53b9d9a615ede21af2351c5efdbf2dcb2f2a7',
    'openbsd_386'   => '895ad630ab3fb503ab0c2afda6259d26a80378cbb0eb35fa2c7e2ab3f1f1bf18',
    'openbsd_amd64' => '47caf008b4937c8276e00a536df459ff590ac5f40621b9475f86b2ed58ddd9ce',
    'solaris_amd64' => '19822ca1c4f8fd47341f8e6a24b41a6b166f4ce37592b94894b0a23ae72cf482',
    'windows_386'   => '50541390d4de9e8906ad60eab2f527ec18660a5e91c3845f7d15e83416706730',
    'windows_amd64' => 'c4d4556665709e0e5b11000413f046e23b365eb97eed9ee04f1a5c2598649356',
  }
  $download_dir        = '/tmp'
  $manage_download_dir = false
  $download_filename   = 'vault.zip'

  # backend and listener are mandatory, we provide some sensible
  # defaults here
  $backend             = { 'file' => { 'path' => '/var/lib/vault' }}
  $manage_backend_dir  = false
  $listener            = {
    'tcp' => {
      'address' => '127.0.0.1:8200',
      'tls_disable' => 1,
    }
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
