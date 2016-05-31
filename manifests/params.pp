# == Class vault::params
#
# This class is meant to be called from vault.
# It sets variables according to platform.
#
class vault::params {
  $user             = 'vault'
  $manage_user      = true
  $group            = 'vault'
  $manage_group     = true
  $bin_dir          = '/usr/local/bin'
  $config_dir       = '/etc/vault'
  $download_url     = 'https://releases.hashicorp.com/vault/0.5.3/vault_0.5.3_linux_amd64.zip'
  $service_name     = 'vault'
  $num_procs        = $::processorcount

  case $::osfamily {
    'Debian': {
      $service_provider = 'upstart'
    }
    'RedHat': {
      if ($::operatingsystemmajrelease == '6') {
        $service_provider = 'redhat'
      } else {
        $service_provider = 'systemd'
      }
    }
    default: {
      fail("Module ${module_name} is not supported on osfamily '${::osfamily}'")
    }
  }
}
