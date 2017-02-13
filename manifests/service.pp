# == Class vault::service
class vault::service {
  if $::vault::manage_service {
    service { $::vault::service_name:
      ensure   => running,
      enable   => true,
      provider => $::vault::service_provider,
    }
  }
}
