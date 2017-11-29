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
#   Manual URL to download the vault zip distribution from.
#
# * `download_url_base`
#   Hashicorp base URL to download vault zip distribution from.
#
# * `download_extension`
#   The extension of the vault download
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

# * `manage_service`
#   Instruct puppet to manage service or not
#
# * `num_procs`
#   Sets the GOMAXPROCS environment variable, to determine how many CPUs Vault
#   can use. The official Vault Terraform install.sh script sets this to the
#   output of ``nprocs``, with the comment, "Make sure to use all our CPUs,
#   because Vault can block a scheduler thread". Default: number of CPUs
#   on the system, retrieved from the ``processorcount`` Fact.
#
# * `version`
#   The version of Vault to install
#
class vault (
  $user                               = $::vault::params::user,
  $manage_user                        = $::vault::params::manage_user,
  $group                              = $::vault::params::group,
  $manage_group                       = $::vault::params::manage_group,
  $bin_dir                            = $::vault::params::bin_dir,
  $config_dir                         = $::vault::params::config_dir,
  $purge_config_dir                   = true,
  $download_url                       = $::vault::params::download_url,
  $download_url_base                  = $::vault::params::download_url_base,
  $download_extension                 = $::vault::params::download_extension,
  $service_name                       = $::vault::params::service_name,
  $service_provider                   = $::vault::params::service_provider,
  $manage_service                     = $::vault::params::manage_service,
  $manage_service_file                = $::vault::params::manage_service_file,
  Hash $storage                       = $::vault::params::storage,
  $manage_storage_dir                 = $::vault::params::manage_storage_dir,
  Hash $listener                      = $::vault::params::listener,
  Optional[Hash] $ha_storage          = $::vault::params::ha_storage,
  Optional[Boolean] $disable_cache    = $::vault::params::disable_cache,
  Optional[Hash] $telemetry           = $::vault::params::telemetry,
  Optional[String] $default_lease_ttl = $::vault::params::default_lease_ttl,
  Optional[String] $max_lease_ttl     = $::vault::params::max_lease_ttl,
  $disable_mlock                      = $::vault::params::disable_mlock,
  $service_options                    = '',
  $num_procs                          = $::vault::params::num_procs,
  $install_method                     = $::vault::params::install_method,
  $package_name                       = $::vault::params::package_name,
  $package_ensure                     = $::vault::params::package_ensure,
  $download_dir                       = $::vault::params::download_dir,
  $manage_download_dir                = $::vault::params::manage_download_dir,
  $download_filename                  = $::vault::params::download_filename,
  $version                            = $::vault::params::version,
  $os                                 = $::vault::params::os,
  $arch                               = $::vault::params::arch,
  Hash $extra_config                  = {},
) inherits ::vault::params {

  # lint:ignore:140chars
  $real_download_url    = pick($download_url, "${download_url_base}${version}/${package_name}_${version}_${os}_${arch}.${download_extension}")
  # lint:endignore

  contain ::vault::install
  contain ::vault::config
  contain ::vault::service

  Class['vault::install'] -> Class['vault::config']
  Class['vault::config'] ~> Class['vault::service']

}
