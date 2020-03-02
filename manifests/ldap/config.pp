# == Class vault::ldap::config
#
#  This class is called from vault to enable vault LDAP authentication.
#
class vault::ldap::config (
  String         $bin_dir          = $vault::bin_dir,
  String         $vault_dir        = $vault::install_dir,
  Array[String]  $ldap_servers     = $vault::ldap_servers,
  String         $bind_dn          = $vault::ldap_bind_dn,
  String         $bind_passwd      = $vault::ldap_bind_passwd,
  String         $user_dn          = $vault::ldap_user_dn,
  String         $user_attr        = $vault::ldap_user_attribute,
  String         $group_dn         = $vault::ldap_group_dn,
  String         $group_attr       = $vault::ldap_group_attribute,
  Boolean        $insecure_tls     = $vault::ldap_insecure_tls,
  String         $vault_token      = $vault::token,
) inherits vault {

  $_ldap_url = join($ldap_servers.map |$server| { "ldap://${server}" }, ",")
  $_ca_cert = "${vault_dir}/certs/${ldap_servers[0]}.crt"
  $_ldap_auth_check_cmd = @("EOC")
    ${bin_dir}/vault auth list -format=json |\
      jq '.[] | {message: .type}' | grep -q 'ldap'
    | EOC
  $_ldap_config_check_cmd = @("EOC")
    ${bin_dir}/vault read -format=json auth/ldap/config |\
      jq '.data.url' | grep -q ${_ldap_url}
    | EOC
  $_ldap_config_cmd = @("EOC")
    vault write auth/ldap/config \
      url="${_ldap_url}" \
      starttls=true \
      insecure_tls=${insecure_tls} \
      certificate=@${_ca_cert} \
      binddn="${bind_dn}" \
      bindpass="${bind_passwd}" \
      userdn="${user_dn}" \
      userattr="${user_attr}" \
      groupdn="${group_dn}" \
      groupfilter="(&(objectClass=group)(member:1.2.840.113556.1.4.1941:={{.UserDN}}))" \
      groupattr="${group_attr}"
    | EOC

#  echo { '>>> DEBUG: _ldap_cmd':
#    message => "\n${_ldap_config_cmd}",
#  }

  exec { 'vault_ldap_enable':
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    command     => 'vault auth enable ldap',
    environment => [ "VAULT_TOKEN=${vault_token}" ],
    unless      => $_ldap_auth_check_cmd,
  }

  exec { 'vault_ldap_config':
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    command     => $_ldap_config_cmd,
    environment => [ "VAULT_TOKEN=${vault_token}" ],
    unless      => $_ldap_config_check_cmd,
  }

}

