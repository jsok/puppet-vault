# @api private == Class to create and configure root certificate of authority
define vault::pki::root_ca (
  Optional[Hash]      $cert_options          = undef,
  String              $common_name           = undef,
  String              $path                  = undef,
  Optional[String]    $role_name             = undef,
  Optional[Hash]      $role_options          = undef,
  Optional[String]    $ttl                   = '720h',
  String              $vault_addr            = $vault::vault_address,
) {

  ## Initialize pki secrets engine
  vault::secrets::engine { $path:
    engine  => 'pki',
    options => {
      'max-lease-ttl' => $ttl,
    },
  }

  ## Generate root public and private certs
  vault::pki::generate_cert { $path:
    common_name  => $common_name,
    pkey_mode    => 'exported',
    cert_options => $cert_options,
    ttl          => $ttl,
    is_root_ca   => true,
  }

  ## Configure root CA urls
  vault::pki::config { $path:
    action  => 'write',
    path    => "${path}/config/urls",
    options => {
      'issuing_certificates'    => "http://${vault_addr}/v1/${path}/ca/pem",
      'crl_distribution_points' => "http://${vault_addr}/v1/${path}/crl/pem",
      #'ocsp_servers'           => (slice),
    },
  }

  ## Configure role for root CA
  if $role_name != undef {
    vault::pki::config { "${path}_role":
      action  => 'write',
      path    => "${path}/roles/${role_name}",
      options => $role_options,
    }
  }

}
