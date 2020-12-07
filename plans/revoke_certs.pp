# @summary Revoke certs for a set of targets
#
# @example
#   $ bolt plan run vault::revoke_certs --targets xxx --params '{"server": "vault.domain.tld", "secret_role": "domain.tld", "auth_method": "ldap", "auth_parameters": {"username": "username@domain.tld", "password": "xxx"}}'
plan vault::revoke_certs(
  String $server,
  String $auth_method,
  String $secret_role,
  Hash $auth_parameters = {},
  Integer $port = 443,
  String $scheme = 'https',
  String $secret_engine = '/pki',
  TargetSpec $targets,
) {
  $_targets = get_targets($targets)
  run_plan('facts', $_targets)
  $revoke_certs = $_targets.reduce([]) |$t_memo, $t| {
    $vault_existing_certs = $t.facts['vault_existing_certs']
    if $vault_existing_certs {
      $target_revoke_certs = $vault_existing_certs.reduce([]) |$c_memo, $item| {
        $k = $item[0]
        $v = $item[1]
        if $v['cert_name'] == $v['common_name'] and $v['cert_name'] == $t.host {
          out::message("Found good cert for ${$t.host}")
          $c_memo + $v['serial_number']
        }
        else {
          $c_memo
        }
      }
      $t_memo + $target_revoke_certs
    }
    else {
      $t_memo
    }
  }
  out::message("revoke certs = ${revoke_certs}")
  run_task('vault::revoke_cert', 'localhost',
            serial_numbers => $revoke_certs,
            server => $server,
            port => $port,
            scheme => $scheme,
            secret_engine => $secret_engine,
            secret_role => $secret_role,
            auth_method => $auth_method,
            auth_parameters => $auth_parameters)
}
