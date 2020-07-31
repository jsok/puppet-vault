# == Class vault::params
#
# This class is meant to be called from vault.
# It sets variables according to platform.
#
class vault::params {
  $install_dir        = '/opt/vault'
  $num_procs          = $facts['processorcount']
  $ip_address         = $facts['networking']['ip']
  $vault_port         = '8200'
  $storage            = { 'file' => { 'path' => '/var/lib/vault' }}
  $manage_storage_dir = false

  $listener = [
    {
      tcp => {
        address     => "127.0.0.1:${vault_port}",
        tls_disable => true,
      },
    },
    {
      tcp => {
        address     => "${ip_address}:${vault_port}",
        tls_disable => true,
      },
    },
  ]

  $api_addr = "http://${ip_address}:${vault_port}"

  # These should always be undef as they are optional settings that
  # should not be configured unless explicitly declared.
  $default_lease_ttl        = undef
  $disable_cache            = undef
  $disable_mlock            = undef
  $ha_storage               = undef
  $manage_file_capabilities = undef
  $max_lease_ttl            = undef
  $seal                     = undef
  $telemetry                = undef

  $service_provider = $facts['service_provider']

  case $facts['architecture'] {
    /(x86_64|amd64|x64)/: { $arch = 'amd64' }
    /(i386|x86)/:         { $arch = '386'   }
    /^arm.*/:             { $arch = 'arm'   }
    default: { fail("Unsupported kernel architecture: ${facts['architecture']}") }
  }

  case $facts['os']['family'] {
    'Archlinux': {
      $install_method      = 'repo'
      $bin_dir             = '/bin'
      $manage_service_file = true
    }
    default: {
      $install_method      = 'archive'
      $bin_dir             = '/usr/local/bin'
      $manage_service_file = undef
    }
  }
  case $facts['os']['family'] {
    'RedHat': {
      $cert_dir            = '/etc/pki/tls/certs'
      $priv_key_dir        = '/etc/pki/tls/private'
    }
    'windows': {
      $cert_dir            = 'Cert:\LocalMachine\My'
      $priv_key_dir        = 'Cert:\LocalMachine\My'
    }
    default: {
      $cert_dir            = '/etc/ssl/certs'
      $priv_key_dir        = '/etc/ssl/private'
    }
  }

  $os = downcase($facts['kernel'])

  ## Default root CA role options
  $root_ca_options = {
    'allow_any_name'        => true,
    'allow_bare_domains'    => true,
    'allow_glob_domains'    => true,
    'allow_ip_sans'         => true,
    'email_protection_flag' => true,
    'enforce_hostnames'     => false,
    'key_bits'              => '256',
    'key_type'              => 'ec',
    'max_ttl'               => '8760h',
  }

  ## These are default vault policies to limit users within vault.
  $default_policies = {
    'admin' => {
      'path' => {
        'auth/*'   => {
          comment      => 'Manage auth methods broadly across Vault',
          capabilities => [ 'create','read','update','delete','list','sudo' ],
        },
        'sys/*'    => {
          comment      => 'List, create, update, and delete sys mounts.',
          capabilities => [ 'create','read','update','delete','list','sudo' ],
        },
        'secret/*' => {
          comment      => 'List, create, update, and delete sys mounts.',
          capabilities => [ 'create','read','update','delete','list','sudo' ],
        },
      }, # end paths
    }, # end admin policy
    'user' => {
      'path' => {
        'auth/*'   => {
          comment      => 'List and read auth methods',
          capabilities => [ 'read','list' ],
        },
        'sys/*'    => {
          comment      => 'List and read sys mounts.',
          capabilities => [ 'read','list' ],
        },
        'secret/*' => {
          comment      => 'List and read secret mounts.',
          capabilities => [ 'read','list' ],
        },
      }, # end paths
    }, # end user policy
  } # end vault policies

}
