require 'spec_helper'

describe 'vault' do
  ['RedHat','Debian'].each do |osfamily|
    context "on #{osfamily}" do
      let(:facts) {{
        :path     => '/usr/local/bin:/usr/bin:/bin',
        :osfamily => "#{osfamily}",
      }}

      context "vault class with simple config_hash only" do
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
        it { is_expected.to contain_class('vault') }

        it { is_expected.to contain_class('vault::params') }
        it { is_expected.to contain_class('vault::install').that_comes_before('vault::config') }
        it { is_expected.to contain_class('vault::config') }
        it { is_expected.to contain_class('vault::service').that_subscribes_to('vault::config') }

        it { is_expected.to contain_service('vault') }
        it { is_expected.to contain_user('vault') }
        it { is_expected.to contain_group('vault') }

        context "do not manage user and group" do
          let(:params) {{
            :manage_user => false,
            :manage_group => false
          }}
          it { is_expected.not_to contain_user('vault') }
          it { is_expected.not_to contain_group('vault') }
        end

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

        it { is_expected.to contain_file('/usr/local/bin/vault').with_mode('0555') }
        it {
          is_expected.to contain_exec('setcap cap_ipc_lock=+ep /usr/local/bin/vault')
            .with_refreshonly('true')
            .that_subscribes_to('File[/usr/local/bin/vault]')
        }

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
      end
    end
  end
  context 'RedHat-specific' do
    let(:facts) {{
      :path     => '/usr/local/bin:/usr/bin:/bin',
      :osfamily => "RedHat",
    }}
    context 'includes SysV init script' do
      it { is_expected.to contain_file('/etc/init.d/vault').with_mode('0755') }
    end
  end
  context 'Debian-specific' do
    let(:facts) {{
      :path     => '/usr/local/bin:/usr/bin:/bin',
      :osfamily => "Debian",
    }}
    context 'includes init link to upstart-job' do
      it {
        is_expected.to contain_file('/etc/init.d/vault')
           .with_ensure('link')
           .with_target('/lib/init/upstart-job')
           .with_mode('0755')
      }
    end
    context 'contains /etc/init/vault.conf' do
      it { is_expected.to contain_file('/etc/init/vault.conf').with_mode('0444') }
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
      it {
        is_expected.to contain_exec('setcap cap_ipc_lock=+ep /opt/bin/vault')
          .with_refreshonly('true')
          .that_subscribes_to('File[/opt/bin/vault]')
      }
      it { is_expected.to contain_file('/opt/etc/vault/config.json') }

      it { is_expected.to contain_file('/opt/bin/vault').with_mode('0555') }
      it {
        is_expected.to contain_file('/opt/etc/vault')
          .with_ensure('directory')
          .with_purge('true') \
          .with_recurse('true')
      }
      it { is_expected.to contain_user('root') }
      it { is_expected.to contain_group('admin') }
    end
  end
  context 'on unsupported osfamily' do
    let(:facts) {{
      :path     => '/usr/local/bin:/usr/bin:/bin',
      :osfamily => 'nexenta',
    }}
    it {
      expect { should contain_class('vault') }.to raise_error(Puppet::Error, /Module vault is not supported on osfamily 'nexenta'/)
    }
  end
end
