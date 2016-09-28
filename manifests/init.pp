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
#   Customise the name of the system service provider; this
#   also controls the init configuration files that are installed.
#
# * `service_options`
#   Extra argument to pass to `vault server`, as per:
#   `vault server --help`
#
# * `num_procs`
#   Sets the GOMAXPROCS environment variable, to determine how many CPUs Vault
#   can use. The official Vault Terraform install.sh script sets this to the
#   output of ``nprocs``, with the comment, "Make sure to use all our CPUs,
#   because Vault can block a scheduler thread". Default: number of CPUs
#   on the system, retrieved from the ``processorcount`` Fact.
#
class vault (
  $user                = $::vault::params::user,
  $manage_user         = $::vault::params::manage_user,
  $group               = $::vault::params::group,
  $manage_group        = $::vault::params::manage_group,
  $bin_dir             = $::vault::params::bin_dir,
  $config_dir          = $::vault::params::config_dir,
  $purge_config_dir    = true,
  $download_url        = $::vault::params::download_url,
  $service_name        = $::vault::params::service_name,
  $service_provider    = $::vault::params::service_provider,
  $backend             = $::vault::params::backend,
  $listener            = $::vault::params::listener,
  $ha_backend          = $::vault::params::ha_backend,
  $disable_cache       = $::vault::params::disable_cache,
  $telemetry           = $::vault::params::telemetry,
  $default_lease_ttl   = $::vault::params::default_lease_ttl,
  $max_lease_ttl       = $::vault::params::max_lease_ttl,
  $disable_mlock       = $::vault::params::disable_mlock,
  $service_options     = '',
  $num_procs           = $::vault::params::num_procs,
  $install_method      = $::vault::params::install_method,
  $package_name        = $::vault::params::package_name,
  $package_ensure      = $::vault::params::package_ensure,
  $download_dir        = $::vault::params::download_dir,
  $manage_download_dir = $::vault::params::manage_download_dir,
  $download_filename   = $::vault::params::download_filename,
) inherits ::vault::params {

  validate_hash($backend)
  validate_hash($listener)

  if $ha_backend {
    validate_hash($ha_backend)
  }

  if $disable_cache {
    validate_bool($disable_cache)
  }

  if $telemetry {
    validate_hash($telemetry)
  }

  if $default_lease_ttl {
    validate_string($default_lease_ttl)
  }

  if $max_lease_ttl {
    validate_string($max_lease_ttl)
  }

  contain vault::install
  contain vault::config
  contain vault::service

  Class['vault::install'] -> Class['vault::config']
  Class['vault::config'] ~> Class['vault::service']

}
