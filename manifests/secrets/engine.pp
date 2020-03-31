# == Class to manage secrets engine @ path
define vault::secrets::engine (
  Optional[Enum[enable,disable,tune]]   $action         = enable,
  String                                $bin_dir        = $vault::bin_dir,
  Enum[kv,pki]                          $engine         = undef,
  Optional[Hash]                        $options        = undef,
  Optional[String]                      $path           = $name,
) {

  ## Parse options if defined
  if $options != undef {
    $_options = join($options.map |$key, $value| { "-${key}='${value}'" }, ' ')
  }

  ## Build vault command
  if $action == 'disable' {
    $_secret_cmd = "vault secrets ${action} ${path}"
    $_check_secret_cmd = 'false'
  } else {
    $_secret_cmd = @("EOC")
      vault secrets ${action} \
        -description="Puppet managed ${engine} engine" \
        -path=${path} ${_options} ${engine}
      | EOC
    $_check_secret_cmd = "vault secrets list | grep -q '${path}/'"
  }

  ## Idemponent configuration file
  file { "${vault::install_dir}/scripts/.engine_${path}_${action}.cmd":
    ensure  => present,
    content => $_secret_cmd,
    mode    => '0640',
  }

  ## Perform selected action
  exec { "pki_enable_${path}":
    command     => $_secret_cmd,
    #environment => "VAULT_TOKEN=${token}",
    path        => [$bin_dir, '/bin', '/usr/bin'],
    unless      => $_check_secret_cmd,
  }

}

