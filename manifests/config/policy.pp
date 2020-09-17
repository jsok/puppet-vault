# == (PRIVATE) Class vault::manage::policy
define vault::config::policy (
  String              $bin_dir         = $vault::bin_dir,
  String              $group           = $vault::group,
  Hash                $path            = undef,
  String              $user            = $vault::user,
  String              $vault_dir       = $vault::install_dir,
) {

  $_policy_file = "${vault_dir}/scripts/${name}.hcl"

  ## Parse policy paths from input.
  $_paths = $path.map |$key, $hash| {
    $cap_data = $hash['capabilities'].map |$c| { "\"${c}\"" }.join(', ')

    $_policy = @("EOC")
      ## ${hash['comment']}
      path "${key}"
      {
        capabilities = [${cap_data}]
      }

      | EOC
  }

  ## Concatenate all paths into single output.
  $_full_policy = $_paths.join()

  ## Write policy content to HCL file format.
  file { $_policy_file:
    ensure  => file,
    content => $_full_policy,
    group   => $group,
    owner   => $user,
  }

  ## Write defined policy to vault if file content changed.
  $_policy_write_cmd = @("EOC")
    bash -lc "${bin_dir}/vault policy write '${name}' '${_policy_file}'"
  | EOC

  exec { "write_${name}":
    command     => $_policy_write_cmd,
    #environment => [ "VAULT_TOKEN=${vault_token}" ],
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    refreshonly => true,
    provider    => 'shell',
    subscribe   => File[$_policy_file],
  }

}
