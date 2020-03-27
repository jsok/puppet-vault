# == Class to configure pki path
define vault::pki::config (
  String[1]             $action           = undef,
  String                $bin_dir          = $vault::bin_dir,
  Optional[Hash]        $options          = undef,
  String[1]             $path             = undef,
  String[1]             $token            = undef,
  String                $vault_dir        = $vault::install_dir,
) {

  ## Unseal vault if needed
  contain vault::config::unseal

  ## Parse options if defined
  if $options != undef {
    $_options = join($options.map |$key, $value| { "${key}='${value}'" }, ' ')
  }

  $_config_cmd = "vault ${action} ${path} ${_options}"

  #notify { "DEBUG: pki_config:\n\n> ${_config_cmd}" : }

  ## Used for idempotencey 
  $_file_name = regsubst($path, '/', '_', 'G')
  file { "${vault_dir}/scripts/.pki_config_${_file_name}.cmd":
    ensure  => present,
    content => $_config_cmd,
    mode    => '0640',
    notify  => Exec["${name}_cmd"],
  }

  exec { "${name}_cmd":
    command     => $_config_cmd,
    environment => "VAULT_TOKEN=${token}",
    path        => $bin_dir,
    refreshonly => true,
  }

}

