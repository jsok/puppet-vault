# @api private == define class to generate pki certificates
define vault::pki::generate_cert (
  String                             $bin_dir          = $vault::bin_dir,
  Optional[Hash]                     $cert_options     = undef,
  Optional[String]                   $cert_sn          = undef,
  String[1]                          $common_name      = undef,
  Boolean                            $is_int_ca        = false,
  Boolean                            $is_root_ca       = false,
  String[1]                          $path             = $name,
  Optional[Enum[internal,exported]]  $pkey_mode        = 'exported',
  String[1]                          $ttl              = '8760h',
  String                             $vault_dir        = $vault::install_dir,
) {

  $cert_bundle = "${vault_dir}/certs/${path}.pem"
  $cert_key    = "${vault_dir}/certs/${path}.key"
  $cert_csr    = "${vault_dir}/certs/${path}.csr"
  $certificate = "${vault_dir}/certs/${path}.crt"

  ## Unseal vault if needed
  contain vault::config::unseal

  ## Parse options if defined
  if $cert_options != undef {
    $_cert_options = join($cert_options.map |$key, $value| { "${key}='${value}'" }, ' ')
  }

  if $is_root_ca {
    # Remove existing root certificate
    $_clear_cert_cmd = @("EOC")
      bash -c "vault delete ${path}/root"
    | EOC
  } else {
    if ! empty($cert_sn) {
      # Revoke existing certificate
      $_clear_cert_cmd = @("EOC")
        bash -c "vault write ${path}/revoke serial_number=${cert_sn}"
      | EOC
    } else {
      $_clear_cert_cmd = @("EOC")
        "vault status"
      | EOC
    }
  }

  ## Check if root or intermediate CA cert
  if $is_root_ca {
    $_gen_cert_cmd = @("EOC")
      bash -c "vault write -format=json ${path}/root/generate/${pkey_mode} \
        common_name='${common_name}' ttl='${ttl}' ${_cert_options} |\
        tee >(jq -r '.data.private_key' > ${cert_key}) |\
        jq -r '.data.certificate' > ${certificate}"
      | EOC
  } elsif $is_int_ca {
    $_gen_cert_cmd = @("EOC")
      bash -c "vault write -format=json ${path}/intermediate/generate/${pkey_mode} \
        common_name='${common_name}' ttl='${ttl}' ${_cert_options} |\
        tee >(jq -r '.data.private_key' > ${cert_key}) |\
        jq -r '.data.csr' > ${cert_csr}"
      | EOC
  }

  $_safe_name = regsubst($common_name, ' ', '_', 'G')
  ## Idempotent command generate certificate script
  file { "${vault_dir}/scripts/.gen_cert_${_safe_name}.cmd":
    ensure  => file,
    content => $_gen_cert_cmd,
    mode    => '0640',
    notify  => Exec["clear_${path}"],
  }

  exec { "clear_${path}":
    command     => $_clear_cert_cmd,
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    refreshonly => true,
    notify      => Exec[$common_name],
  }

  ## Export root CA certifcate
  exec { $common_name:
    command     => $_gen_cert_cmd,
    path        => [ $bin_dir, '/bin', '/usr/bin' ],
    refreshonly => true,
  }

}
