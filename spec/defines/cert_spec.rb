require 'spec_helper'

RSpec.describe 'vault::cert' do
  let(:title) { 'hostname.domain.tld.crt' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        let(:params) do
          {
            'ensure' => 'present',
            'api_secret_role' => 'pki_role',
            'api_server' => 'vault.domain.tld',
          }
        end

        let(:cert_dir) do
          (os_facts[:os]['family'] == 'RedHat') ? '/etc/pki/tls/certs' : '/etc/ssl/certs'
        end

        let(:priv_key_dir) do
          (os_facts[:os]['family'] == 'RedHat') ? '/etc/pki/tls/private' : '/etc/ssl/private'
        end

        it do
          is_expected.to contain_vault_cert(title)
            .with('ensure' => 'present',
                  'api_secret_role' => 'pki_role',
                  'api_server' => 'vault.domain.tld',
                  'cert_name' => 'hostname.domain.tld.crt',
                  'cert_dir' => cert_dir,
                  'priv_key_dir' => priv_key_dir)
        end

        if os_facts[:os]['family'] != 'windows'
          it do
            is_expected.to contain_file("#{cert_dir}/hostname.domain.tld.crt")
              .with('ensure' => 'present',
                    'owner'  => 'root',
                    'group'  => 'root',
                    'mode'   => '0644')
              .that_subscribes_to('Vault_cert[hostname.domain.tld.crt]')
          end
          it do
            is_expected.to contain_file("#{priv_key_dir}/hostname.domain.tld.key")
              .with('ensure' => 'present',
                    'owner'  => 'root',
                    'group'  => 'root',
                    'mode'   => '0600')
              .that_subscribes_to('Vault_cert[hostname.domain.tld.crt]')
          end
        end
      end
    end
  end
end
