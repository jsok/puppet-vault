# == define class to manage secrets engine @ path

# Class vault::secrets::engine
#
# Parameters
# ----------
#
# * `action`
#   Optional list of actions [enable (default), disable, or tune]
#
# * `engine`
#   Supported list of configurable vault engines [kv or pki]
#
# * `options`
#   A Hash of configuration parameters for the specified engine to manage.
#
# * `path`
#   The path in vault to create/manage the specified engine.


define vault::secrets::engine (
  Optional[Enum[enable,disable,tune]]   $action         = enable,
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
    $_secret_cmd = @("EOC")
      bash -lc "${vault::bin_dir}/vault secrets ${action} ${path}"
    | EOC
    $_check_secret_cmd = 'false'
  } else {
    $_secret_cmd = @("EOC"/L)
      bash -lc "${vault::bin_dir}/vault secrets ${action} \
        -description=\"Puppet managed ${engine} engine\" \
        -path=${path} ${_options} ${engine}"
    | EOC
    $_check_secret_cmd = @("EOC")
      bash -lc "${vault::bin_dir}/vault secrets list | grep -q \"${path}/\""
    | EOC
  }

  ## Perform selected action
  exec { "pki_enable_${path}":
    command  => $_secret_cmd,
    path     => [ $vault::bin_dir, '/bin', '/usr/bin' ],
    unless   => $_check_secret_cmd,
    provider => 'shell',
  }

}
