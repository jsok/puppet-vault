# Class: vault
# ===========================
#
# Full description of class vault here.
#
# Parameters
# ----------
#
# * `user`
#   Customise the user vault runs as, will also create the user unless `manage_user` is false.
#
# * `manage_user`
#   Whether or not the module should create the user.
#
# * `group`
#   Customise the group vault runs as, will also create the user unless `manage_group` is false.
#
# * `manage_group`
#   Whether or not the module should create the group.
#
# * `bin_dir`
#   Directory the vault executable will be installed in.
#
# * `config_dir`
#   Directory the vault configuration will be kept in.
#
# * `purge_config_dir`
#   Whether the `config_dir` should be purged before installing the
#   generated config.
#
# * `download_url`
#   URL to download the vault zip distribution from.
#
# * `service_name`
#   Customise the name of the system service
#
# * `service_provider`
#   Customise the name of the system service provider
#
# * `config_hash`
#   A hash representing vault's config (in JSON) as per:
#   https://vaultproject.io/docs/config/index.html
#
# * `service_options`
#   Extra argument to pass to `vault server`, as per:
#   `vault server --help`
#
class vault (
  $user             = $::vault::params::user,
  $manage_user      = $::vault::params::manage_user,
  $group            = $::vault::params::group,
  $manage_group     = $::vault::params::manage_group,
  $bin_dir          = $::vault::params::bin_dir,
  $config_dir       = $::vault::params::config_dir,
  $purge_config_dir = true,
  $download_url     = $::vault::params::download_url,
  $service_name     = $::vault::params::service_name,
  $service_provider = $::vault::params::service_provider,
  $config_hash      = {},
  $service_options  = '',
) inherits ::vault::params {
  validate_hash($config_hash)

  contain vault::install
  contain vault::config
  contain vault::service

  Class['vault::install'] -> Class['vault::config']
  Class['vault::config'] ~> Class['vault::service']

}
