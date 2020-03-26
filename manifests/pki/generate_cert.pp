# == Class to generate pki certificates 
define vault::pki::generate_cert (
  String                             $bin_dir          = $vault::bin_dir,
  Optional[String]                   $cert_sn          = undef,
  String[1]                          $common_name      = undef,
  Boolean                            $is_int_ca        = false,
  Boolean                            $is_root_ca       = false,
  Optional[Hash]                     $options          = undef,
  String[1]                          $path             = $name,
  Optional[Enum[internal,exported]]  $pkey_mode        = 'exported',
  String[1]                          $token            = undef,
  String[1]                          $ttl              = '8760h',
  String                             $vault_dir        = $vault::install_dir,
) {

  $cert_bundle = "${vault_dir}/certs/${path}.pem"
  $cert_key    = "${vault_dir}/certs/${path}.key"
  $cert_csr    = "${vault_dir}/certs/${path}.csr"

  ## Unseal vault if needed
  contain vault::configure::unseal

  ## Parse options if defined
  if $options != undef {
    $_options = join($options.map |$key, $value| { "${key}='${value}'" }, ' ')
  }

  if $is_root_ca {
    # Remove existing root certificate
    $_clear_cert_cmd = "vault delete ${path}/root"
  } else {
    if ! empty($cert_sn) {
      # Revoke existing certificate
      $_clear_cert_cmd = "vault write ${path}/revoke serial_number=${cert_sn}"
    } else {
      # NOOP
      $_clear_cert_cmd = 'vault status'
    }
  }

  ## Check if root or intermediate CA cert
  if $is_root_ca {
    $_gen_cert_cmd = @("EOC")
      vault write -format=json ${path}/root/generate/${pkey_mode} \
        common_name='${common_name}' ttl='${ttl}' ${_options} |\
        jq -r '.data.private_key, .data.certificate' > ${cert_bundle}
      | EOC
  } else {
    if $is_int_ca {
      $_gen_cert_cmd = @("EOC")
        bash -c "vault write -format=json ${path}/intermediate/generate/${pkey_mode} \
          common_name='${common_name}' ttl='${ttl}' ${_options} |\
          tee >(jq -r '.data.private_key' > ${cert_key}) |\
          jq -r '.data.csr' > ${cert_csr}"
        | EOC
    }

  }

  $_safe_name = regsubst($common_name, ' ', '_', 'G')
  ## Idempotent command generate certificate script
  file { "${vault_dir}/scripts/.gen_cert_${_safe_name}.cmd":
    ensure  => present,
    content => $_gen_cert_cmd,
    mode    => '0640',
    notify  => Exec["clear_${path}"],
  }

  exec { "clear_${path}":
    command     => $_clear_cert_cmd,
    environment => "VAULT_TOKEN=${token}",
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    refreshonly => true,
    notify      => Exec[$common_name],
  }

  ## Export root CA certifcate
  # NOTE: File /${vault_dir}/certs/${common_name}.pem must be absent to prevent
  #       overwriting existing certificate file.
  exec { $common_name:
    command     => $_gen_cert_cmd,
    environment => "VAULT_TOKEN=${token}",
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    refreshonly => true,
  }

}

