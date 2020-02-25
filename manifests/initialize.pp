# == Class vault::initialize 
#
#  This class is called from vault to initialize vault after installation.
#
class vault::initialize {

  $bin_dir          = $vault::bin_dir
  $vault_dir        = $vault::install_dir
  $minimum_keys     = $vault::min_keys
  $total_keys       = $vault::total_keys
  $vault_addr       = "${vault::ip_address}:${vault::vault_port}"

  $init_cmd = @("EOC")
    vault operator init \
      -key-shares=${total_keys} \
      -key-threshold=${minimum_keys} |\
      tee ${vault_dir}/vault_init.txt
    | EOC

  if str2bool($facts['vault_initialized']) != true {
    exec { 'vault_initialize':
      path    => [$bin_dir, '/bin', '/usr/bin'],
      command => $init_cmd,
      creates => "${vault_dir}/vault_init.txt",
    }

    facter::fact { 'vault_initialized':
      value => true,
    }

    file { "${vault_dir}/vault_init.txt":
      owner => 'root',
      group => 'root',
      mode  => '0640',
    }
  }

  ## Create profile script
  file { '/etc/profile.d/vault.sh':
    ensure  => present,
    content => template('vault/vault.profile.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

}
