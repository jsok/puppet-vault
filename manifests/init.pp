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
# * `package_name`
#   Defaults to vault, used to form the download url
#   using download_url_base when download_url is undefined.
#
# * `download_url`
#   URL to download the vault zip distribution from.
#
# * `download_url_base`
#   Customised URL base to download the vault zip distribution from.
#   Defaults to "https://releases.hashicorp.com/vault/"
#
# * `download_extension`
#   Defaults to zip. Used to form the download url
#   using download_url_base when download_url is undefined.
#
# * `version`
#   Version of vault to download and install. Valid only if download_url is undefined.
#
# * `service_name`
#   Customise the name of the system service
#
# * `service_provider`
#   Customise the name of the system service provider; this
#   also controls the init configuration files that are installed.
#
# * `config_hash`
#   A hash representing vault's config (in JSON) as per:
#   https://vaultproject.io/docs/config/index.html
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
# * `os`
#   Defaults to the value of downcase of fact ``kernel``
#   Used to form the download url using download_url_base when download_url is undefined.
#
# * arch
#   Derieved from fact ``architecture``.
#   Used to form the download url using download_url_base when download_url is undefined.
#
class vault (
  $user               = $::vault::params::user,
  $manage_user        = $::vault::params::manage_user,
  $group              = $::vault::params::group,
  $manage_group       = $::vault::params::manage_group,
  $bin_dir            = $::vault::params::bin_dir,
  $config_dir         = $::vault::params::config_dir,
  $purge_config_dir   = true,
  $package_name       = $::vault::params::package_name,
  $download_url       = undef,
  $download_url_base  = $::vault::params::download_url_base,
  $download_extension = $::vault::params::download_extension,
  $version            = $::vault::params::version,
  $service_name       = $::vault::params::service_name,
  $service_provider   = $::vault::params::service_provider,
  $config_hash        = {},
  $service_options    = '',
  $num_procs          = $::vault::params::num_procs,
  $os                 = $::vault::params::os,
  $arch               = $::vault::params::arch,
) inherits ::vault::params {
  validate_hash($config_hash)

  $real_download_url = pick($download_url,"${download_url_base}/${version}/${package_name}_${version}_${os}_${arch}.${download_extension}")

  contain vault::install
  contain vault::config
  contain vault::service

  Class['vault::install'] -> Class['vault::config']
  Class['vault::config'] ~> Class['vault::service']

}
