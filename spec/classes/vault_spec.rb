require 'spec_helper'

describe 'vault' do
  ['RedHat','Debian'].each do |osfamily|
    if osfamily == 'Debian'
      let(:facts) {{
        :path => '/usr/local/bin:/usr/bin:/bin',
        :osfamily => 'Debian',
      }}
    end

    if osfamily == 'RedHat'
      let(:facts) {{
        :path => '/usr/local/bin:/usr/bin:/bin',
        :osfamily => 'RedHat',
      }}
    end


    if osfamily == 'RedHat' || osfamily== 'Debian'
      context "vault class without any parameters" do
        let(:params) {{
          :config_hash => {
            'advertise_addr' => '0.0.0.0',
            'backend' => {
              'file' => {
                'path' => '/data/vault'
              }
            },
            'listener' => {
              'tcp' => {
                'address'     => '127.0.0.1:8200',
                'tls_disable' => 1,
              }
            }
          }
        }}

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('vault::params') }
        it { is_expected.to contain_class('vault::install').that_comes_before('vault::config') }
        it { is_expected.to contain_class('vault::config') }
        it { is_expected.to contain_class('vault::service').that_subscribes_to('vault::config') }

        it { is_expected.to contain_service('vault') }
        it { is_expected.to contain_user('vault') }
        it { is_expected.to contain_group('vault') }

        it {
          is_expected.to contain_file('/etc/vault')
            .with_ensure('directory')
            .with_purge('true') \
            .with_recurse('true')
        }
        it {
          is_expected.to contain_file('/etc/vault/config.json') \
            .with_content(/"advertise_addr":\s*"0.0.0.0"/)
            .with_content(/"backend":\s*{\s*"file":\s*{\s*"path":\s*"\/data\/vault"/)
            .with_content(/"listener":\s*{\s*"tcp":/)
            .with_content(/"address":\s*"127.0.0.1:8200"/)
            .with_content(/"tls_disable":\s*1/)
        }

        it { is_expected.to contain_file('/etc/init/vault.conf').with_mode('0444') }
        it {
          is_expected.to contain_file('/etc/init.d/vault')
             .with_ensure('link')
             .with_target('/lib/init/upstart-job')
             .with_mode('0755')
        }

        it { is_expected.to contain_file('/usr/local/bin/vault').with_mode('0555') }
        it {
          is_expected.to contain_exec('setcap cap_ipc_lock=+ep /usr/local/bin/vault')
            .with_refreshonly('true')
            .that_subscribes_to('File[/usr/local/bin/vault]')
        }
      end

      context "disable mlock" do
        let(:params) {{
          'config_hash' => {
            'disable_mlock' => true
          }
        }}
        it { is_expected.not_to contain_exec('setcap cap_ipc_lock=+ep /usr/local/bin/vault') }

        it {
          is_expected.to contain_file('/etc/vault/config.json')
            .with_content(/"disable_mlock":\s*true/)
        }
      end

      context "installs from download url" do
        let(:params) {{
          :download_url => 'http://example.com/vault.zip',
        }}

        it {
          is_expected.to contain_staging__deploy('vault.zip')
            .with_source('http://example.com/vault.zip')
            .that_notifies('File[/usr/local/bin/vault]')
        }
      end

      context "service with modified options" do
        let(:params) {{
          :bin_dir => '/opt/bin',
          :config_dir => '/opt/etc/vault',
          :service_options => '-log-level=info',
          :user => 'root',
          :group => 'admin',
        }}
        it {
          is_expected.to contain_file('/etc/init/vault.conf')
            .with_content(/env USER=root/)
            .with_content(/env GROUP=admin/)
            .with_content(/env CONFIG=\/opt\/etc\/vault\/config.json/)
            .with_content(/env VAULT=\/opt\/bin\/vault/)
            .with_content(/start-stop-daemon .* -log-level=info$/)
        }
      end
    end

    if osfamily == 'RedHat'
      context "installs from download url" do
        it { is_expected.to contain_file('/etc/init.d/vault').with_mode('0755') }
      end
    end
    
  end
end
