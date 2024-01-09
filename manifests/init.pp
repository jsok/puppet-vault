# Class: vault
# ===========================
#
# Full description of class vault here.
#
# Parameters
# ----------
#
# @param user
# @param manage_user
# @param group
# @param manage_group
# @param bin_dir
# @param config_dir
# @param manage_config_file
# @param config_mode
# @param purge_config_dir
# @param download_url
# @param download_url_base
# @param download_extension
# @param service_name
# @param service_enable
# @param service_ensure
# @param service_provider
# @param manage_service
# @param manage_service_file
# @param storage
# @param manage_storage_dir
# @param listener
# @param ha_storage
# @param seal
# @param disable_cache
# @param telemetry
# @param default_lease_ttl
# @param max_lease_ttl
# @param disable_mlock
# @param manage_file_capabilities
# @param service_options
# @param num_procs
# @param install_method
# @param package_name
# @param package_ensure
# @param download_dir
# @param manage_download_dir
# @param download_filename
# @param version
# @param os
# @param arch
# @param enable_ui
# @param api_addr
# @param extra_config
#
class vault (
  String $user                                = $vault::params::user,
  Boolean $manage_user                        = $vault::params::manage_user,
  String $group                               = $vault::params::group,
  Boolean $manage_group                       = $vault::params::manage_group,
  String $bin_dir                             = $vault::params::bin_dir,
  String $config_dir                          = $vault::params::config_dir,
  Boolean $manage_config_file                 = $vault::params::manage_config_file,
  String $config_mode                         = $vault::params::config_mode,
  Boolean $purge_config_dir                   = true,
  Optional[String] $download_url              = $vault::params::download_url,
  String $download_url_base                   = $vault::params::download_url_base,
  String $download_extension                  = $vault::params::download_extension,
  String $service_name                        = $vault::params::service_name,
  String $service_enable                      = $vault::params::service_enable,
  String $service_ensure                      = $vault::params::service_ensure,
  String $service_provider                    = $vault::params::service_provider,
  Boolean $manage_service                     = $vault::params::manage_service,
  Optional[Boolean] $manage_service_file      = $vault::params::manage_service_file,
  Hash $storage                               = $vault::params::storage,
  Boolean $manage_storage_dir                 = $vault::params::manage_storage_dir,
  Variant[Hash, Array[Hash]] $listener        = $vault::params::listener,
  Optional[Hash] $ha_storage                  = $vault::params::ha_storage,
  Optional[Hash] $seal                        = $vault::params::seal,
  Optional[Boolean] $disable_cache            = $vault::params::disable_cache,
  Optional[Hash] $telemetry                   = $vault::params::telemetry,
  Optional[String] $default_lease_ttl         = $vault::params::default_lease_ttl,
  Optional[String] $max_lease_ttl             = $vault::params::max_lease_ttl,
  Optional[Boolean] $disable_mlock            = $vault::params::disable_mlock,
  Optional[Boolean] $manage_file_capabilities = $vault::params::manage_file_capabilities,
  Optional[String] $service_options           = undef,
  Integer $num_procs                          = $vault::params::num_procs,
  String $install_method                      = $vault::params::install_method,
  String $package_name                        = $vault::params::package_name,
  String $package_ensure                      = $vault::params::package_ensure,
  String $download_dir                        = $vault::params::download_dir,
  Boolean $manage_download_dir                = $vault::params::manage_download_dir,
  String $download_filename                   = $vault::params::download_filename,
  String $version                             = $vault::params::version,
  String $os                                  = $vault::params::os,
  String $arch                                = $vault::params::arch,
  Optional[Boolean] $enable_ui                = $vault::params::enable_ui,
  Optional[String] $api_addr                  = undef,
  Hash $extra_config                          = {},
) inherits vault::params {
  # lint:ignore:140chars
  $real_download_url = pick($download_url, "${download_url_base}${version}/${package_name}_${version}_${os}_${arch}.${download_extension}")
  # lint:endignore

  contain vault::install
  contain vault::config
  contain vault::service

  Class['vault::install'] -> Class['vault::config']
  Class['vault::config'] ~> Class['vault::service']
}
