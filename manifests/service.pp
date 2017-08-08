# == Class vault::service
class vault::service {
  if $::vault::manage_service {
    
    if $::vault::manage_proxy {
      if $::vault::proxy_address == undef {
        fail("manage_proxy is true, but proxy address has not been set!")
      }
    }
    
    service { $::vault::service_name:
      ensure   => running,
      enable   => true,
      provider => $::vault::service_provider,
    }
  }
}
