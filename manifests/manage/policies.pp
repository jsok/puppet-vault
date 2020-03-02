# == (PRIVATE) Class vault::manage::policies
define vault::manage::policies (
  String                    $bin_dir        = $vault::bin_dir,
  String                    $vault_token    = $vault::token,
  Optional[Array[String]]   $capabilities   = undef,
  Optional[String]          $comment        = undef,
  Hash                      $path           = undef,
  Optional[String]          $policy         = undef,
) {

  $_policy_file = "${vault::install_dir}/${name}.hcl"

  file { $_policy_file:
    ensure => absent,
  }

  $path.each | $key, $hash| {
    $cap_data = $hash['capabilities'].map |$c| { "\"${c}\"" }.join(', ')

    $_policy = @("EOC")
      ## ${hash['comment']}
      path "${key}"
      {
        capabilities = [$cap_data]
      }
      | EOC

    exec { "${_policy_name}.${key}":
      path    => [ '/bin', '/usr/bin' ],
      command => "echo '${_policy}' >> ${_policy_file}",
    }
  }

}
