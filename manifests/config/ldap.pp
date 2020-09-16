# == Class vault::ldap
#
#  This class is called from vault to enable vault LDAP authentication.
#
define vault::config::ldap (
  String           $bin_dir          = $vault::bin_dir,
  String           $bind_dn          = undef,
  String           $bind_passwd      = undef,
  String           $group_attr       = undef,
  String           $group_dn         = undef,
  String           $group_filter     =
    '(&(objectClass=group)(member:1.2.840.113556.1.4.1941:={{.UserDN}}))',
  String           $group            = $vault::group,
  Boolean          $insecure_tls     = undef,
  Optional[Hash]   $ldap_groups      = $vault::ldap_groups,
  Optional[String] $ldap_url         = undef,
  Array[String]    $ldap_servers     = undef,
  Boolean          $starttls         = undef,
  String           $user_attr        = undef,
  String           $user_dn          = undef,
  String           $user             = $vault::user,
  String           $vault_address    = $vault::vault_address,
  String           $vault_dir        = $vault::install_dir,
) {

  $_ldap_cert = "${vault_dir}/certs/${ldap_servers[0]}.crt"

  $_ldap_cert_cmd = @("EOC")
    openssl s_client -connect ${ldap_servers[0]}:636 2>&1 <<< "Q" |\
      sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' \
      > ${vault_dir}/certs/${ldap_servers[0]}.crt
    | EOC

  $_ldap_auth_check_cmd = @("EOC")
    bash -c "${bin_dir}/vault auth list -format=json |\
      jq '.[] | {message: .type}' | grep -q 'ldap'"
    | EOC

  if $ldap_url == undef {
    $_ldap_url = $ldap_servers.map |$server| { "ldap://${server}" }.join(',')
  }
  else {
    $_ldap_url = $ldap_url
  }

  ## Unseal vault if needed
  contain vault::config::unseal

  exec { "${ldap_servers[0]}.crt":
    path    => [ '/bin', '/usr/bin' ],
    command => $_ldap_cert_cmd,
    creates => $_ldap_cert,
  }

  exec { 'vault_ldap_enable':
    path    => [ $bin_dir, '/bin', '/usr/bin' ],
    command => 'bash -c "vault auth enable ldap"',
    #environment => [ "VAULT_TOKEN=${vault_token}" ],
    unless  => $_ldap_auth_check_cmd,
    require => Exec["${vault_dir}/scripts/unseal.sh"],
  }

  $_ldap_config_cmd = @("EOC")
    bash -c "vault write auth/ldap/config \
      url='${_ldap_url}' \
      starttls='${starttls}' \
      insecure_tls='${insecure_tls}' \
      certificate=@'${_ldap_cert}' \
      binddn='${bind_dn}' \
      bindpass='${bind_passwd}' \
      userdn='${user_dn}' \
      userattr='${user_attr}' \
      groupdn='${group_dn}' \
      groupattr='${group_attr}' \
      groupfilter='${group_filter}'"
    | EOC

  $_safe_ldap_cmd = regsubst($_ldap_config_cmd, "bindpass='.* ", "bindpass='********' ",)

  #notify { 'DEBUG_safe_ldap_cmd': message => $_safe_ldap_cmd }

  file { "${vault_dir}/scripts/.ldap_config_${name}.cmd":
    ensure  => file,
    content => $_safe_ldap_cmd,
    mode    => '0640',
    notify  => Exec["ldap_config_${name}"],
  }

  exec { "ldap_config_${name}":
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    command     => $_ldap_config_cmd,
    #environment => [ "VAULT_TOKEN=${vault_token}" ],
    refreshonly => true,
  }

  if $ldap_groups != undef {
    create_resources ('vault::config::ldap_groups', $ldap_groups)
  }

}
