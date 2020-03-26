# == Class vault::manage::initialize 
#
#  This class is called from vault to initialize vault after installation.
#
class vault::configure::initialize (
  String         $bin_dir        = $vault::bin_dir,
  String         $vault_dir      = $vault::install_dir,
  Integer        $minimum_keys   = $vault::min_keys,
  Integer        $total_keys     = $vault::total_keys,
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
    ensure  => present,
    content => template('vault/vault.profile.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

}
