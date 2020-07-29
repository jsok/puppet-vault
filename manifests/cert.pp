# @summary a vault certificate that also amanges the ownership and mode of the generated
#          certificate files (for use on Linux)
define vault::cert (
  String  $ensure,
  String  $api_server,
  String  $api_secret_role,
  Optional[String] $common_name       = undef,
  Optional[Array[String]] $alt_names  = undef,
  Optional[Array[String]] $ip_sans    = undef,
  # API options
  Optional[String] $api_auth_method   = undef,
  Optional[Hash] $api_auth_parameters = undef,
  Optional[String] $api_auth_path     = undef,
  Optional[String] $api_auth_token    = undef,
  Optional[Integer] $api_port         = undef,
  Optional[String] $api_scheme        = undef,
  Optional[String] $api_secret_engine = undef,
  # Cert options
  Optional[String] $cert            = undef,
  Optional[String] $cert_dir        = undef,
  String $cert_group                = 'root',
  String $cert_owner                = 'root',
  Stdlib::Filemode $cert_mode       = '0644',
  Optional[String] $cert_name       = $title,
  Optional[String] $cert_ttl        = undef,
  # Private Key options
  Optional[String] $priv_key        = undef,
  Optional[String] $priv_key_dir    = undef,
  Optional[String] $priv_key_group  = undef,
  Optional[String] $priv_key_owner  = undef,
  Stdlib::Filemode $priv_key_mode   = '0600',
  Optional[String] $priv_key_name   = undef,
  # Other options
  Boolean $manage_files             = true,
  Optional[Integer] $regenerate_ttl = undef,
) {
  include vault::params
  $_cert_dir = pick($cert_dir, $vault::params::cert_dir)
  $_cert_path = stdlib::extname($cert_name) ? {
    ''      => "${_cert_dir}/${cert_name}.crt",
    undef   => "${_cert_dir}/${cert_name}.crt",
    default => "${_cert_dir}/${cert_name}",
  }

  $_priv_key_dir = pick($priv_key_dir, $vault::params::priv_key_dir)
  $_cert_no_ext = basename($cert_name, stdlib::extname($cert_name))
  $_priv_key_file = pick($priv_key_name, "${_cert_no_ext}.key")
  $_priv_key_path = "${_priv_key_dir}/${_priv_key_file}"

  vault_cert { $title:
    ensure              => $ensure,
    common_name         => $common_name,
    alt_names           => $alt_names,
    ip_sans             => $ip_sans,
    api_auth_method     => $api_auth_method,
    api_auth_parameters => $api_auth_parameters,
    api_auth_path       => $api_auth_path,
    api_auth_token      => $api_auth_token,
    api_port            => $api_port,
    api_scheme          => $api_scheme,
    api_secret_engine   => $api_secret_engine,
    api_secret_role     => $api_secret_role,
    api_server          => $api_server,
    cert                => $cert,
    cert_name           => $cert_name,
    cert_dir            => $_cert_dir,
    cert_ttl            => $cert_ttl,
    priv_key            => $priv_key,
    priv_key_name       => $priv_key_name,
    priv_key_dir        => $_priv_key_dir,
    regenerate_ttl      => $regenerate_ttl,
  }

  if $manage_files and $facts['os']['family'] != 'windows' {
    file { $_cert_path:
      ensure    => $ensure,
      owner     => $cert_owner,
      group     => $cert_group,
      mode      => $cert_mode,
      subscribe => Vault_cert[$title],
    }

    $_priv_key_owner = pick($priv_key_owner, $cert_owner)
    $_priv_key_group = pick($priv_key_group, $cert_owner)
    file { $_priv_key_path:
      ensure    => $ensure,
      owner     => $_priv_key_owner,
      group     => $_priv_key_group,
      mode      => $priv_key_mode,
      subscribe => Vault_cert[$title],
    }
  }
}
