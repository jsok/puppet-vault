# == Class vault::ldap 
#
#  This class is called from vault to enable vault LDAP authentication.
#
class vault::ldap (
  String             $vault_dir        = $vault::install_dir,
  Array[String]      $ldap_servers     = $vault::ldap_servers,
  Optional[Hash]     $ldap_groups      = $vault::ldap_groups,
) inherits vault {

  if $vault_initialized != true {
    fail("\n---> You must initialize vault before configuring ldap.")
  }

  $_ca_cert = "${vault_dir}/certs/${ldap_servers[0]}.crt"
  $_ca_cert_cmd = @("EOC")
    openssl s_client -connect ${ldap_servers[0]}:636 2>&1 <<< "Q" |\
      sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' \
      > ${vault_dir}/certs/${ldap_servers[0]}.crt
    | EOC

  ## Unseal vault if needed
  contain vault::manage::unseal

  $_vault_utils = [ 'openssl', 'jq' ]
  package { $_vault_utils: ensure => present }

  file { "${vault_dir}/certs":
    ensure => directory,
    owner  => $vault::user,
    group  => $vault::group,
    mode   => '0750',
  }

  exec { "${ldap_servers[0]}.crt":
    path    => [ '/bin', '/usr/bin' ],
    command => $_ca_cert_cmd,
    creates => $_ca_cert,
  }

  contain vault::ldap::config

  if $ldap_groups != undef {
    create_resources ('vault::ldap::groups', $ldap_groups)
  }

}

