# Class: vault
# ===========================
#
# Full description of class vault here.
#
# Parameters
# ----------
#
# * `sample parameter`
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
class vault (
  $user             = $::vault::params::user,
  $group            = $::vault::params::group,
  $bin_dir          = $::vault::params::bin_dir,
  $config_dir       = $::vault::params::config_dir,
  $purge_config_dir = true,
  $download_url     = $::vault::params::download_url,
  $service_name     = $::vault::params::service_name,
  $config_hash      = {},
  $service_options  = '',
) inherits ::vault::params {
  validate_hash($config_hash)

  class { '::vault::install': } ->
  class { '::vault::config': } ~>
  class { '::vault::service': } ->
  Class['::vault']
}
