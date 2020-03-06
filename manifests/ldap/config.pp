# == Class vault::ldap::config
#
#  This class is called from vault to enable vault LDAP authentication.
#
class vault::ldap::config (
  String             $bin_dir          = $vault::bin_dir,
  String             $vault_dir        = $vault::install_dir,
  Array[String]      $ldap_servers     = $vault::ldap_servers,
  String             $bind_dn          = $vault::ldap_bind_dn,
  String             $bind_passwd      = $vault::ldap_bind_passwd,
  String             $user_dn          = $vault::ldap_user_dn,
  String             $user_attr        = $vault::ldap_user_attribute,
  String             $group_dn         = $vault::ldap_group_dn,
  String             $group_attr       = $vault::ldap_group_attribute,
  Boolean            $insecure_tls     = $vault::ldap_insecure_tls,
  Boolean            $starttls         = $vault::ldap_starttls,
  String             $vault_address    = $vault::vault_address,
  String             $vault_token      = $vault::token,
  String             $group            = $vault::group,
  String             $user             = $vault::user,
) inherits vault {

  $_ca_cert = "${vault_dir}/certs/${ldap_servers[0]}.crt"

  $_ldap_url = join($ldap_servers.map |$server| { "ldap://${server}" }, ",")
  
  $_ldap_auth_check_cmd = @("EOC")
    ${bin_dir}/vault auth list -format=json |\
      jq '.[] | {message: .type}' | grep -q 'ldap'
    | EOC

  file { "${vault_dir}/scripts/config_ldap.sh":
    ensure  => present,
    content => template('vault/vault.ldap_config.erb'),
    owner   => $user,
    group   => $group,
    mode    => '0750',
    notify  => Exec['vault_ldap_config'],
  }

  exec { 'vault_ldap_enable':
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    command     => 'vault auth enable ldap',
    environment => [ "VAULT_TOKEN=${vault_token}" ],
    unless      => $_ldap_auth_check_cmd,
  }

  exec { 'vault_ldap_config':
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    command     => "${vault_dir}/scripts/config_ldap.sh",
    environment => [ "VAULT_TOKEN=${vault_token}" ],
    refreshonly => true,
  }

}

