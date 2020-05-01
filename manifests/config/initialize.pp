# == Class vault::manage::initialize
#
#  This class is called from vault to initialize vault after installation.
#
class vault::config::initialize (
  String              $bin_dir        = $vault::bin_dir,
  Integer             $minimum_keys   = $vault::min_keys,
  Integer             $total_keys     = $vault::total_keys,
  String              $vault_dir      = $vault::install_dir,
  Optional[String]    $vault_token    = $vault::token,
) inherits vault {

  $_init_cmd = @("EOC")
    vault operator init \
      -key-shares=${total_keys} \
      -key-threshold=${minimum_keys} \
      > ${vault_dir}/vault_init.txt
    | EOC

  if $facts['vault_initialized'] != true {
    exec { 'vault_initialize':
      path    => [$bin_dir, '/bin', '/usr/bin'],
      command => $_init_cmd,
      creates => "${vault_dir}/vault_init.txt",
    }

    file { "${vault_dir}/vault_init.txt":
      owner => 'root',
      group => 'root',
      mode  => '0640',
    }
  }

  ## Create profile script
  file { '/etc/profile.d/vault.sh':
    ensure  => file,
    content => template('vault/vault.profile.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  ## Set vault token in home directory
  if empty($vault_token) {

    # Look for root token in vault_init.txt if $vault_token undef
    $_set_token_cmd = @("EOC"/$)
      grep 'Root Token' "${vault_dir}/vault_init.txt" |\
        awk -F': ' '{ print \$2 }' > /root/.vault-token
      | EOC

    exec { 'store_vault_token':
      command => $_set_token_cmd,
      path    => '/bin',
      creates => '/root/.vault-token',
    }

  } else {

    # Set vault token to defined $vault_token
    file { '/root/.vault-token':
      ensure  => file,
      content => $vault_token,
      owner   => root,
      group   => root,
      mode    => '0600',
    }

  }

  contain vault::config::unseal

}
