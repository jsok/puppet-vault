# == Class vault::ldap 
#
#  This class is called from vault to enable vault LDAP authentication.
#
class vault::ldap (
  String             $vault_dir        = $vault::install_dir,
  Array[String]      $ldap_servers     = $vault::ldap_servers,
  Optional[Hash]     $ldap_policies    = $vault::ldap_policies,
) inherits vault {

  $_ca_cert = "${vault_dir}/certs/${ldap_servers[0]}.crt"
  $_ca_cert_cmd = @("EOC")
    openssl s_client -connect ${ldap_servers[0]}:636 2>&1 <<< "Q" |\
      sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' \
      > ${vault_dir}/certs/${ldap_servers[0]}.crt
    | EOC

  ## Unseal vault if needed
  contain vault::unseal

  package { 'vault_openssl':
    ensure => present,
    name   => 'openssl',
  }

  file { "${vault_dir}/certs":
    ensure => directory,
    owner  => $vault::user,
    group  => $vault::group,
    mode   => '0750',
  }

  exec { "${ldap_servers[0]}.crt":
    path        => [ '/bin', '/usr/bin' ],
    command     => $_ca_cert_cmd,
  }

  if str2bool($facts['vault_ldap_enabled']) != true {
    contain vault::ldap::config
  }

  create_resources ('vault::ldap::policies', $ldap_policies)

}

