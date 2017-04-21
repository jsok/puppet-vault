require 'spec_helper'

describe 'vault' do
  ['RedHat','Debian'].each do |osfamily|
    context "on #{osfamily}" do
      let(:facts) {{
        :path           => '/usr/local/bin:/usr/bin:/bin',
        :osfamily       => "#{osfamily}",
        :processorcount => '3',
        :architecture   => 'x86_64',
        :kernel         => 'Linux',
      }}

      context "vault class with simple configuration" do
        let(:params) {{
          :backend => {
            'file' => {
              'path' => '/data/vault'
            }
            },
          :listener => {
            'tcp' => {
              'address'     => '127.0.0.1:8200',
              'tls_disable' => 1,
            }
          }
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('vault') }

        it { is_expected.to contain_class('vault::params') }
        it { is_expected.to contain_class('vault::install').that_comes_before('Class[vault::config]') }
        it { is_expected.to contain_class('vault::config') }
        it { is_expected.to contain_class('vault::service').that_subscribes_to('Class[vault::config]') }

        it { is_expected.to contain_service('vault')
          .with_ensure('running')
          .with_enable(true)
        }
        it { is_expected.to contain_user('vault') }
        it { is_expected.to contain_group('vault') }
        it { is_expected.not_to contain_file('/data/vault') }

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
            .with_purge('true')
            .with_recurse('true')
            .with_owner('vault')
            .with_group('vault')
        }
        it {
          is_expected.to contain_file('/etc/vault/config.json')
            .with_owner('vault')
            .with_group('vault')
            .with_content(/"backend":\s*{\s*"file":\s*{\s*"path":\s*"\/data\/vault"/)
            .with_content(/"listener":\s*{\s*"tcp":/)
            .with_content(/"address":\s*"127.0.0.1:8200"/)
            .with_content(/"tls_disable":\s*1/)
        }

        it { is_expected.to contain_file('/usr/local/bin/vault').with_mode('0555') }
        it {
          is_expected.to contain_exec('setcap cap_ipc_lock=+ep /usr/local/bin/vault')
            .with_unless('getcap /usr/local/bin/vault | grep cap_ipc_lock+ep')
            .that_subscribes_to('File[/usr/local/bin/vault]')
        }

        context "disable mlock" do
          let(:params) {{
              :disable_mlock => true
          }}
          it { is_expected.not_to contain_exec('setcap cap_ipc_lock=+ep /usr/local/bin/vault') }

          it {
            is_expected.to contain_file('/etc/vault/config.json')
              .with_content(/"disable_mlock":\s*true/)
          }
        end

        context "default download options" do
          let(:params) {{ :version  => '0.7.0' }}
          it {
            is_expected.to contain_archive('/tmp/vault.zip')
              .with_source('https://releases.hashicorp.com/vault/0.7.0/vault_0.7.0_linux_amd64.zip')
              .that_comes_before('File[/usr/local/bin/vault]')
          }
        end

        context "specifying a custom download params" do
          let(:params) {{
            :version  => '0.6.0',
            :download_url_base => 'http://my_site.example.com/vault/',
            :package_name => 'vaultbinary',
            :download_extension => 'tar.gz'
          }}

          it {
            is_expected.to contain_archive('/tmp/vault.zip')
              .with_source('http://my_site.example.com/vault/0.6.0/vaultbinary_0.6.0_linux_amd64.tar.gz')
              .that_comes_before('File[/usr/local/bin/vault]')
          }
        end

        context "installs from download url" do
          let(:params) {{
            :download_url   => 'http://example.com/vault.zip',
            :install_method => 'archive',
          }}

          it {
            is_expected.to contain_archive('/tmp/vault.zip')
              .with_source('http://example.com/vault.zip')
              .that_comes_before('File[/usr/local/bin/vault]')
          }
        end

        context "installs from repository" do
          let(:params) {{
            :install_method => 'repo',
            :package_name   => 'vault',
            :package_ensure => 'installed',
          }}

          it { should contain_package('vault') }
        end
      end

      context "when specifying manage_service" do
        let(:params) {{
          :manage_service => false,
          :backend => {
            'file' => {
              'path' => '/data/vault'
            }
            }
        }}

        it { is_expected.to_not contain_service('vault')
          .with_ensure('running')
          .with_enable(true)
        }
      end

      context "when specifying manage_backend_dir" do
        let(:params) {{
          :manage_backend_dir => true,
          :backend => {
            'file' => {
              'path' => '/data/vault'
            }
            }
        }}

        it {
          is_expected.to contain_file('/data/vault')
            .with_ensure('directory')
            .with_owner('vault')
            .with_group('vault')
        }
      end
    end
  end
  context 'RedHat 7 Amazon Linux specific' do
   let(:facts) {{
      :path                      => '/usr/local/bin:/usr/bin:/bin',
      :osfamily                  => 'RedHat',
      :operatingsystem           => 'Amazon',
      :operatingsystemmajrelease => '7',
      :processorcount            => '3',
      :architecture              => 'x86_64',
      :kernel                    => 'Linux',
   }}
   context 'includes SysV init script' do
      it {
        is_expected.to contain_file('/etc/init.d/vault')
          .with_mode('0755')
          .with_ensure('file')
          .with_owner('root')
          .with_group('root')
          .with_content(%r{^#!/bin/sh})
          .with_content(/export GOMAXPROCS=\${GOMAXPROCS:-3}/)
          .with_content(%r{daemon --user vault "{ \$exec server -config=\$conffile \$OPTIONS &>> \$logfile & }; echo \\\$\! >\| \$pidfile"})
          .with_content(%r{OPTIONS=\$OPTIONS:-""})
          .with_content(%r{exec="/usr/local/bin/vault"})
          .with_content(%r{conffile="/etc/vault/config.json"})
          .with_content(%r{chown vault \$logfile \$pidfile})
      }
    end
    context 'service with non-default options' do
      let(:params) {{
        :bin_dir => '/opt/bin',
        :config_dir => '/opt/etc/vault',
        :service_options => '-log-level=info',
        :user => 'root',
        :group => 'admin',
        :num_procs => '5',
      }}
      it {
        is_expected.to contain_file('/etc/init.d/vault')
          .with_mode('0755')
          .with_ensure('file')
          .with_owner('root')
          .with_group('root')
          .with_content(%r{^#!/bin/sh})
          .with_content(/export GOMAXPROCS=\${GOMAXPROCS:-5}/)
          .with_content(%r{daemon --user root "{ \$exec server -config=\$conffile \$OPTIONS &>> \$logfile & }; echo \\\$\! >\| \$pidfile"})
          .with_content(%r{OPTIONS=\$OPTIONS:-"-log-level=info"})
          .with_content(%r{exec="/opt/bin/vault"})
          .with_content(%r{conffile="/opt/etc/vault/config.json"})
          .with_content(%r{chown root \$logfile \$pidfile})
      }
    end
    context 'does not include systemd reload' do
      it {
        is_expected.to_not contain_exec('systemd-reload')
      }
    end
  end
  context 'RedHat 6 specific' do
    let(:facts) {{
      :path                      => '/usr/local/bin:/usr/bin:/bin',
      :osfamily                  => 'RedHat',
      :operatingsystemmajrelease => '6',
      :processorcount            => '3',
      :architecture              => 'x86_64',
      :kernel                    => 'Linux',
    }}
    context 'includes SysV init script' do
      it {
        is_expected.to contain_file('/etc/init.d/vault')
          .with_mode('0755')
          .with_ensure('file')
          .with_owner('root')
          .with_group('root')
          .with_content(%r{^#!/bin/sh})
          .with_content(/export GOMAXPROCS=\${GOMAXPROCS:-3}/)
          .with_content(%r{daemon --user vault "{ \$exec server -config=\$conffile \$OPTIONS &>> \$logfile & }; echo \\\$\! >\| \$pidfile"})
          .with_content(%r{OPTIONS=\$OPTIONS:-""})
          .with_content(%r{exec="/usr/local/bin/vault"})
          .with_content(%r{conffile="/etc/vault/config.json"})
          .with_content(%r{chown vault \$logfile \$pidfile})
      }
    end
    context 'service with non-default options' do
      let(:params) {{
        :bin_dir => '/opt/bin',
        :config_dir => '/opt/etc/vault',
        :service_options => '-log-level=info',
        :user => 'root',
        :group => 'admin',
        :num_procs => '5',
      }}
      it {
        is_expected.to contain_file('/etc/init.d/vault')
          .with_mode('0755')
          .with_ensure('file')
          .with_owner('root')
          .with_group('root')
          .with_content(%r{^#!/bin/sh})
          .with_content(/export GOMAXPROCS=\${GOMAXPROCS:-5}/)
          .with_content(%r{daemon --user root "{ \$exec server -config=\$conffile \$OPTIONS &>> \$logfile & }; echo \\\$\! >\| \$pidfile"})
          .with_content(%r{OPTIONS=\$OPTIONS:-"-log-level=info"})
          .with_content(%r{exec="/opt/bin/vault"})
          .with_content(%r{conffile="/opt/etc/vault/config.json"})
          .with_content(%r{chown root \$logfile \$pidfile})
      }
    end
    context 'does not include systemd reload' do
      it {
        is_expected.to_not contain_exec('systemd-reload')
      }
    end
  end
  context 'RedHat >=7 specific' do
    let(:facts) {{
      :path                      => '/usr/local/bin:/usr/bin:/bin',
      :osfamily                  => 'RedHat',
      :operatingsystemmajrelease => '7',
      :processorcount            => '3',
      :architecture              => 'x86_64',
      :kernel                    => 'Linux',
    }}
    context 'includes systemd init script' do
      it {
        is_expected.to contain_file('/etc/systemd/system/vault.service')
          .with_mode('0644')
          .with_ensure('file')
          .with_owner('root')
          .with_group('root')
          .with_notify('Exec[systemd-reload]')
          .with_content(/^# vault systemd unit file/)
          .with_content(/^User=vault$/)
          .with_content(/^Group=vault$/)
          .with_content(/Environment=GOMAXPROCS=3/)
          .with_content(%r{^ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json $})
          .with_content(/SecureBits=keep-caps/)
          .with_content(/Capabilities=CAP_IPC_LOCK\+ep/)
          .with_content(/CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK/)
          .with_content(/NoNewPrivileges=yes/)
      }
    end
    context 'service with non-default options' do
      let(:params) {{
        :bin_dir => '/opt/bin',
        :config_dir => '/opt/etc/vault',
        :service_options => '-log-level=info',
        :user => 'root',
        :group => 'admin',
        :num_procs => 8,
      }}
      it {
        is_expected.to contain_file('/etc/systemd/system/vault.service')
          .with_mode('0644')
          .with_ensure('file')
          .with_owner('root')
          .with_group('root')
          .with_notify('Exec[systemd-reload]')
          .with_content(/^# vault systemd unit file/)
          .with_content(/^User=root$/)
          .with_content(/^Group=admin$/)
          .with_content(/Environment=GOMAXPROCS=8/)
          .with_content(%r{^ExecStart=/opt/bin/vault server -config=/opt/etc/vault/config.json -log-level=info$})
      }
    end
    context 'with mlock disabled' do
      let(:params) {{
        :disable_mlock   => true,
        :backend => {
          'file' => {
            'path' => '/data/vault'
          }
        },
        :listener => {
          'tcp' => {
            'address'     => '127.0.0.1:8200',
            'tls_disable' => 1,
          }
        }
      }}
      it {
        is_expected.to contain_file('/etc/systemd/system/vault.service')
          .with_mode('0644')
          .with_ensure('file')
          .with_owner('root')
          .with_group('root')
          .with_notify('Exec[systemd-reload]')
          .with_content(/^# vault systemd unit file/)
          .with_content(/^User=vault$/)
          .with_content(/^Group=vault$/)
          .with_content(%r{^ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json $})
          .without_content(/SecureBits=keep-caps/)
          .without_content(/Capabilities=CAP_IPC_LOCK\+ep/)
          .with_content(/CapabilityBoundingSet=CAP_SYSLOG/)
          .with_content(/NoNewPrivileges=yes/)
      }
    end
    context 'includes systemd reload' do
      it {
        is_expected.to contain_exec('systemd-reload')
          .with_command('systemctl daemon-reload')
          .with_path('/bin:/usr/bin:/sbin:/usr/sbin')
          .with_user('root')
          .with_refreshonly(true)
      }
    end
  end
  ['trusty','vivid'].each do |lsbdistcodename|
    context "Ubuntu-#{lsbdistcodename}-specific" do
      let(:facts) {{
                     :path            => '/usr/local/bin:/usr/bin:/bin',
                     :osfamily        => 'Debian',
                     :lsbdistcodename => "#{lsbdistcodename}",
                     :processorcount  => '3',
                     :architecture    => 'x86_64',
                     :kernel          => 'Linux',
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
        it {
          is_expected.to contain_file('/etc/init/vault.conf')
                          .with_mode('0444')
                          .with_ensure('file')
                          .with_owner('root')
                          .with_group('root')
                          .with_content(/^# vault Agent \(Upstart unit\)/)
                          .with_content(/env USER=vault/)
                          .with_content(/env GROUP=vault/)
                          .with_content(/env CONFIG=\/etc\/vault\/config.json/)
                          .with_content(/env VAULT=\/usr\/local\/bin\/vault/)
                          .with_content(/exec start-stop-daemon -u \$USER -g \$GROUP -p \$PID_FILE -x \$VAULT -S -- server -config=\$CONFIG $/)
                          .with_content(/export GOMAXPROCS=\${GOMAXPROCS:-3}/)
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
        it {
          is_expected.to contain_exec('setcap cap_ipc_lock=+ep /opt/bin/vault')
                          .with_unless('getcap /opt/bin/vault | grep cap_ipc_lock+ep')
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
  end
  ['jessie','stretch','sid','xenial','yakketi', 'zesty'].each do |lsbdistcodename|
    context "Debian/Ubuntu #{lsbdistcodename} specific (systemd)" do
      let(:facts) {{
                     :path            => '/usr/local/bin:/usr/bin:/bin',
                     :osfamily        => 'Debian',
                     :lsbdistcodename => "#{lsbdistcodename}",
                     :processorcount  => '3',
                     :architecture    => 'x86_64',
                     :kernel          => 'Linux',
                   }}
      context 'includes systemd init script' do
        it {
          is_expected.to contain_file('/etc/systemd/system/vault.service')
                          .with_mode('0644')
                          .with_ensure('file')
                          .with_owner('root')
                          .with_group('root')
                          .with_notify('Exec[systemd-reload]')
                          .with_content(/^# vault systemd unit file/)
                          .with_content(/^User=vault$/)
                          .with_content(/^Group=vault$/)
                          .with_content(/Environment=GOMAXPROCS=3/)
                          .with_content(%r{^ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json $})
                          .with_content(/SecureBits=keep-caps/)
                          .with_content(/Capabilities=CAP_IPC_LOCK\+ep/)
                          .with_content(/CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK/)
                          .with_content(/NoNewPrivileges=yes/)
        }
      end
      context 'service with non-default options' do
        let(:params) {{
                        :bin_dir => '/opt/bin',
                        :config_dir => '/opt/etc/vault',
                        :service_options => '-log-level=info',
                        :user => 'root',
                        :group => 'admin',
                        :num_procs => 8,
                      }}
        it {
          is_expected.to contain_file('/etc/systemd/system/vault.service')
                          .with_mode('0644')
                          .with_ensure('file')
                          .with_owner('root')
                          .with_group('root')
                          .with_notify('Exec[systemd-reload]')
                          .with_content(/^# vault systemd unit file/)
                          .with_content(/^User=root$/)
                          .with_content(/^Group=admin$/)
                          .with_content(/Environment=GOMAXPROCS=8/)
                          .with_content(%r{^ExecStart=/opt/bin/vault server -config=/opt/etc/vault/config.json -log-level=info$})
        }
      end
      context 'with mlock disabled' do
        let(:params) {{
                        :disable_mlock   => true,
                        :backend => {
                          'file' => {
                            'path' => '/data/vault'
                          }
                        },
                        :listener => {
                          'tcp' => {
                            'address'     => '127.0.0.1:8200',
                            'tls_disable' => 1,
                          }
                        }
                      }}
        it {
          is_expected.to contain_file('/etc/systemd/system/vault.service')
                          .with_mode('0644')
                          .with_ensure('file')
                          .with_owner('root')
                          .with_group('root')
                          .with_notify('Exec[systemd-reload]')
                          .with_content(/^# vault systemd unit file/)
                          .with_content(/^User=vault$/)
                          .with_content(/^Group=vault$/)
                          .with_content(%r{^ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json $})
                          .without_content(/SecureBits=keep-caps/)
                          .without_content(/Capabilities=CAP_IPC_LOCK\+ep/)
                          .with_content(/CapabilityBoundingSet=CAP_SYSLOG/)
                          .with_content(/NoNewPrivileges=yes/)
        }
      end
      context 'includes systemd reload' do
        it {
          is_expected.to contain_exec('systemd-reload')
                          .with_command('systemctl daemon-reload')
                          .with_path('/bin:/usr/bin:/sbin:/usr/sbin')
                          .with_user('root')
                          .with_refreshonly(true)
        }
      end
    end
  end
  context 'Invalid service_provider' do
    let(:facts) {{
      :path                      => '/usr/local/bin:/usr/bin:/bin',
      :osfamily                  => 'RedHat',
      :operatingsystemmajrelease => '6',
      :processorcount            => '3',
      :architecture              => 'x86_64',
      :kernel                    => 'Linux',
    }}
    let(:params) {{
      :service_provider => 'foo',
    }}
    context 'fails with a helpful message' do
      it {
        expect { should contain_class('vault::config') }
          .to raise_error(Puppet::Error, /vault::service_provider 'foo' is not valid/)
      }
    end
  end
  context 'on unsupported osfamily' do
    let(:facts) {{
      :path           => '/usr/local/bin:/usr/bin:/bin',
      :osfamily       => 'nexenta',
      :processorcount => '3',
    }}
    it {
      expect { should contain_class('vault') }.to raise_error(Puppet::Error, /Module vault is not supported on osfamily 'nexenta'/)
    }
  end
end
