# == Class vault::service
class vault::service {
  service { $::vault::service_name:
    ensure   => running,
    enable   => true,
    provider => 'upstart',
  }
}
