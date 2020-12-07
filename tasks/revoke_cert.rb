#!/usr/bin/env ruby
require_relative '../../ruby_task_helper/files/task_helper.rb'
require_relative '../../vault/lib/puppet_x/encore/vault/client'

# Bolt task for enabling/disabling monitoring alerts in SolarWinds
class VaultRevokeCertTask < TaskHelper
  def add_module_lib_paths(install_dir)
    Dir.glob(File.join([install_dir, '*'])).each do |mod|
      $LOAD_PATH << File.join([mod, 'lib'])
    end
  end

  def task(serial_numbers: nil,
           server: nil,
           port: nil,
           scheme: nil,
           secret_engine: nil,
           secret_role: nil,
           auth_method: nil,
           auth_token: nil,
           auth_parameters: {},
           **kwargs)
    # stringify keys in hash
    auth_parameters = auth_parameters.collect{|k,v| [k.to_s, v]}.to_h
    
    client = PuppetX::Encore::Vault::Client.new(api_server: server,
                                                api_port: port,
                                                api_scheme: scheme,
                                                api_secret_engine: secret_engine,
                                                api_secret_role: secret_role,
                                                api_auth_method: auth_method,
                                                api_auth_token: auth_token,
                                                api_auth_parameters: auth_parameters)
    serial_numbers = [serial_numbers] unless serial_numbers.is_a?(Array)
    serial_numbers.each do |sn|
      client.revoke_cert(sn)
    end
  end
end

VaultRevokeCertTask.run if $PROGRAM_NAME == __FILE__
