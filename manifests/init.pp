# Class: vault
# ===========================
#
# Full description of class vault here.
#
# Parameters
# ----------
#
# * `install_dir`
#   The installation directory to install Vault to (Default: /opt/vault).
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
#   Directory the vault executable will be linked to (Default: /usr/local/bin).
#
# * `config_dir`
#   Directory the vault configuration will be kept in (Default: /etc/vault).
#
# * `config_mode`
#   Mode of the configuration file (config.json) (Default: '0750').
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
# * `api_addr`
#   Specifies the address (full URL) to advertise to other Vault servers in the
#   cluster for client redirection. This value is also used for plugin backends.
#   This can also be provided via the environment variable VAULT_API_ADDR. In
#   general this should be set as a full URL that points to the value of the
#   listener address (Example: http://vault.domain.com:8200).
#
# * `version`
#   The version of Vault to install
#
# == Class vault::initialize
# * `initialize_vault`
#   If set to true, will initialize vault after installation.  Keys and tokens
#   are stored in $install_dir/vault_init.txt file.
#
# * `total_keys`
#   Specify the total number of keys created to unseal Vault (Default: 5).
#
# * `min_keys`
#   The minimum number of keys needed to unseal Vault (Default: 2).
#
class vault (
  Optional[String]           $api_addr                  = $vault::params::api_addr,
  String                     $arch                      = $vault::params::arch,
  String                     $bin_dir                   = $vault::params::bin_dir,
  String                     $config_dir                = '/etc/vault',
  String                     $config_mode               = '0750',
  Optional[String]           $consul_port               = '8500',
  Optional[String]           $consul_url                = undef,
  Optional[String]           $default_lease_ttl         = $vault::params::default_lease_ttl,
  Optional[Boolean]          $disable_cache             = $vault::params::disable_cache,
  Optional[Boolean]          $disable_mlock             = $vault::params::disable_mlock,
  String                     $download_dir              = '/tmp',
  String                     $download_extension        = 'zip',
  Optional[String]           $download_filename         = 'vault.zip',
  String                     $download_url_base         = 'https://releases.hashicorp.com/vault/',
  Optional[String]           $download_url              = undef,
  Boolean                    $enable_ldap               = true,
  Optional[Boolean]          $enable_ui                 = true,
  Optional[Hash]             $extra_config              = {},
  String                     $group                     = 'vault',
  Optional[Hash]             $ha_storage                = $vault::params::ha_storage,
  String                     $install_method            = $vault::params::install_method,
  String                     $install_dir               = '/opt/vault',
  Optional[Boolean]          $initialize_vault          = true,
  Integer                    $total_keys                = 5,
  Integer                    $min_keys                  = 2,
  String                     $ip_address                = $vault::params::ip_address,
  Variant[Hash,Array[Hash]]  $listener                  = $vault::params::listener,
  Boolean                    $manage_download_dir       = false,
  Optional[Boolean]          $manage_file_capabilities  = $vault::params::manage_file_capabilities,
  Boolean                    $manage_group              = true,
  Boolean                    $manage_pki                = true,
  Optional[Boolean]          $manage_service_file       = $vault::params::manage_service_file,
  Boolean                    $manage_service            = true,
  Boolean                    $manage_storage_dir        = true,
  Boolean                    $manage_user               = true,
  Optional[String]           $max_lease_ttl             = $vault::params::max_lease_ttl,
  Integer                    $num_procs                 = $vault::params::num_procs,
  String                     $os                        = $vault::params::os,
  Enum['present','installed','absent','purged','latest']
    $package_ensure                                     = 'installed',
  Optional[String]           $package_name              = 'vault',
  Boolean                    $purge_config_dir          = true,
  Optional[Hash]             $seal                      = $vault::params::seal,
  Boolean                    $service_enable            = true,
  Enum['stopped','running']  $service_ensure            = 'running',
  String                     $service_name              = 'vault',
  Optional[String]           $service_options           = undef,
  String                     $service_provider          = $vault::params::service_provider,
  Optional[Hash]             $storage                   = undef,
  Optional[Hash]             $telemetry                 = $vault::params::telemetry,
  String                     $user                      = 'vault',
  String                     $vault_port                = $vault::params::vault_port,
  String                     $version                   = '1.3.2',
) inherits ::vault::params {

  $_download_url  = "${download_url_base}${version}"
  $_download_file = "${package_name}_${version}_${os}_${arch}.${download_extension}"

  $real_download_url = pick($download_url, "${_download_url}/${_download_file}")

  contain ::vault::install
  contain ::vault::config
  contain ::vault::service

  Class['vault::install'] -> Class['vault::config']
  Class['vault::config'] ~> Class['vault::service']

  if $initialize_vault {
    contain vault::initialize
  }

}
