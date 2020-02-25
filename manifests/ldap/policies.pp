# == Class vault::ldap::policies
define vault::ldap::policies (
  String          $bin_dir        = $vault::bin_dir,
  String          $vault_token    = $vault::token,
  String          $group          = undef,
  String          $policy         = undef,
) {

  $_vault_cmd = @("EOC")
    vault write auth/ldap/groups/${group} policies=${policy}
    | EOC

  exec { "vault_${group}":
    path    => $bin_dir,
    command => $_vault_cmd,
  }

}
