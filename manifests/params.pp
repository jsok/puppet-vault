# == Class vault::params
#
# This class is meant to be called from vault.
# It sets variables according to platform.
#
class vault::params {
  $user         = 'vault'
  $group        = 'vault'
  $bin_dir      = '/usr/local/bin'
  $config_dir   = '/etc/vault'
  $download_url = 'https://dl.bintray.com/mitchellh/vault/vault_0.3.1_linux_amd64.zip'
  $service_name = 'vault'
}
