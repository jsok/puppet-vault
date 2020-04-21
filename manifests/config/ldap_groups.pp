# == (PRIVATE) Class vault::ldap::groups
define vault::config::ldap_groups (
  String              $bin_dir        = $vault::bin_dir,
  String              $group          = undef,
  String              $policy         = undef,
) {

  $_group_add_cmd = @("EOC")
    vault write auth/ldap/groups/${group} policies=${policy}
    | EOC
  $_group_check_cmd = @("EOC")
    ${bin_dir}/vault read -format=json auth/ldap/groups/${group} |\
      jq .data.policies | grep -q "${policy}"
    | EOC

  exec { "vault_${group}":
    path        => [ $bin_dir, '/bin', '/usr/local/bin' ],
    command     => $_group_add_cmd,
    #environment => [ "VAULT_TOKEN=${vault_token}" ],
    unless      => $_group_check_cmd,
  }

}
