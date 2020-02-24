# == Class vault::unseal
#
#  This class is called from vault to initialize vault after installation.
#
class vault::unseal (
  String                   $vault_bin_dir     = $vault::bin_dir,
  String                   $vault_dir         = $vault::install_dir,
  Integer                  $vault_min_keys    = $vault::min_keys,
  Optional[Array[String]]  $vault_keys        = lookup('vault::unseal::keys') |$k| undef,
  Integer                  $vault_total_keys  = $vault::total_keys,
  String                   $vault_user        = $vault::user
  String                   $vault_group       = $vault::group
) {

  file { "${vault_dir}/scripts":
    ensure => 'directory',
    owner  => $vault_user,
    group  => $vault_group,
    mode   => '0750',
  }

  ## Create unseal bash script.
  ~> file { "${vault_dir}/scripts/unseal.sh":
    ensure  => file,
    content => template('vault/vault.unseal.erb'),
    owner   => $vault_user,
    group   => $vault_group,
    mode    => '0750',
  }

  ## Unseal vault
  exec { "${vault_dir}/scripts/unseal.sh":
    path    => "/bin:${vault_bin_dir}",
    require => File["${vault_dir}/scripts/unseal.sh"],
    unless  => 'vault status',
  }

}
