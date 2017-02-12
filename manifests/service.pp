# == Class vault::service
class vault::service {
  if $::vault::service_managed {
    service { $::vault::service_name:
      ensure   => running,
      enable   => true,
      provider => $::vault::service_provider,
    }
  }
}
