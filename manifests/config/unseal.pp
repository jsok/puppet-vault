# == Class vault::manage::unseal
#
#  This class is called from vault to initialize vault after installation.
#
class vault::config::unseal (
  String                   $bin_dir           = $vault::bin_dir,
  String                   $vault_addr        = $vault::vault_address,
  String                   $vault_dir         = $vault::install_dir,
  Integer                  $minimum_keys      = $vault::min_keys,
  Optional[Array[String]]  $vault_keys        = $vault::vault_keys,
  String                   $vault_user        = $vault::user,
  String                   $vault_group       = $vault::group,
) inherits vault {

  file { "${vault_dir}/scripts":
    ensure => 'directory',
    owner  => $vault_user,
    group  => $vault_group,
    mode   => '0750',
  }

  ## Create unseal bash script.
  -> file { "${vault_dir}/scripts/unseal.sh":
    ensure  => file,
    content => template('vault/vault.unseal.erb'),
    owner   => $vault_user,
    group   => $vault_group,
    mode    => '0750',
  }

  ## Unseal vault
  exec { "${vault_dir}/scripts/unseal.sh":
    path     => [ $bin_dir, '/bin', '/usr/bin' ],
    require  => File["${vault_dir}/scripts/unseal.sh"],
    unless   => "${bin_dir}/vault status",
    provider => 'shell',
  }

}
