require 'spec_helper'

describe 'vault' do
  let :node do
    'agent.example.com'
  end

  on_supported_os.each do |os, facts|
    context "on #{os} " do
      let :facts do
        facts.merge(service_provider: 'init', processorcount: 3)
      end

      context 'vault class with simple configuration' do
        let(:params) do
          {
            storage: {
              'file' => {
                'path' => '/data/vault'
              }
            },
            listener: {
              'tcp' => {
                'address'     => '127.0.0.1:8200',
                'tls_disable' => 1
              }
            }
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('vault') }

        it { is_expected.to contain_class('vault::params') }
        it { is_expected.to contain_class('vault::install').that_comes_before('Class[vault::config]') }
        it { is_expected.to contain_class('vault::config') }
        it { is_expected.to contain_class('vault::service').that_subscribes_to('Class[vault::config]') }

        it {
          is_expected.to contain_service('vault').
            with_ensure('running').
            with_enable(true)
        }
        it { is_expected.to contain_user('vault') }
        it { is_expected.to contain_group('vault') }
        it { is_expected.not_to contain_file('/data/vault') }

        context 'do not manage user and group' do
          let(:params) do
            {
              manage_user: false,
              manage_group: false
            }
          end

          it { is_expected.not_to contain_user('vault') }
          it { is_expected.not_to contain_group('vault') }
        end

        it {
          is_expected.to contain_file('/etc/vault').
            with_ensure('directory').
            with_purge('true').
            with_recurse('true').
            with_owner('vault').
            with_group('vault')
        }
        it {
          is_expected.to contain_file('/etc/vault/config.json').
            with_owner('vault').
            with_group('vault').
            with_content(/"storage":\s*{\s*"file":\s*{\s*"path":\s*"\/data\/vault"/).
            with_content(%r{"address":\s*"127.0.0.1:8200"}).
            with_content(%r{"tls_disable":\s*1})
        }

        it { is_expected.to contain_file('/usr/local/bin/vault').with_mode('0755') }
        it {
          is_expected.to contain_exec('setcap cap_ipc_lock=+ep /usr/local/bin/vault').
            with_unless('getcap /usr/local/bin/vault | grep cap_ipc_lock+ep').
            that_subscribes_to('File[/usr/local/bin/vault]')
        }

        context 'disable mlock' do
          let(:params) do
            {
              disable_mlock: true
            }
          end

          it { is_expected.not_to contain_exec('setcap cap_ipc_lock=+ep /usr/local/bin/vault') }

          it {
            is_expected.to contain_file('/etc/vault/config.json').
              with_content(%r{"disable_mlock":\s*true})
          }
        end

        context 'default download options' do
          let(:params) { { version: '0.7.0' } }

          it {
            is_expected.to contain_archive('/tmp/vault.zip').
              with_source('https://releases.hashicorp.com/vault/0.7.0/vault_0.7.0_linux_amd64.zip').
              that_comes_before('File[/usr/local/bin/vault]')
          }
        end

        context 'specifying a custom download params' do
          let(:params) do
            {
              version: '0.6.0',
              download_url_base: 'http://my_site.example.com/vault/',
              package_name: 'vaultbinary',
              download_extension: 'tar.gz'
            }
          end

          it {
            is_expected.to contain_archive('/tmp/vault.zip').
              with_source('http://my_site.example.com/vault/0.6.0/vaultbinary_0.6.0_linux_amd64.tar.gz').
              that_comes_before('File[/usr/local/bin/vault]')
          }
        end

        context 'installs from download url' do
          let(:params) do
            {
              download_url: 'http://example.com/vault.zip',
              install_method: 'archive'
            }
          end

          it {
            is_expected.to contain_archive('/tmp/vault.zip').
              with_source('http://example.com/vault.zip').
              that_comes_before('File[/usr/local/bin/vault]')
          }
        end

        context 'installs from repository' do
          let(:params) do
            {
              install_method: 'repo',
              package_name: 'vault',
              package_ensure: 'installed'
            }
          end

          it { is_expected.to contain_package('vault') }
        end
      end

      context 'when specifying manage_service' do
        let(:params) do
          {
            manage_service: false,
            storage: {
              'file' => {
                'path' => '/data/vault'
              }
            }
          }
        end

        it {
          is_expected.not_to contain_service('vault').
            with_ensure('running').
            with_enable(true)
        }
      end

      context 'when specifying manage_storage_dir' do
        let(:params) do
          {
            manage_storage_dir: true,
            storage: {
              'file' => {
                'path' => '/data/vault'
              }
            }
          }
        end

        it {
          is_expected.to contain_file('/data/vault').
            with_ensure('directory').
            with_owner('vault').
            with_group('vault')
        }
      end
      case facts[:os]['family']
      when 'RedHat'
        case facts[:os]['release']['major'].to_i
        when 2017
          context 'RedHat 7 Amazon Linux specific' do
            let facts do
              facts.merge(service_provider: 'sysv', processorcount: 3)
            end

            context 'includes SysV init script' do
              it {
                is_expected.to contain_file('/etc/init.d/vault').
                  with_mode('0755').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^#!/bin/sh}).
                  with_content(%r{export GOMAXPROCS=\${GOMAXPROCS:-3}}).
                  with_content(%r{OPTIONS=\$OPTIONS:-""}).
                  with_content(%r{exec="/usr/local/bin/vault"}).
                  with_content(%r{conffile="/etc/vault/config.json"}).
                  with_content(%r{chown vault \$logfile \$pidfile})
              }
            end
            context 'service with non-default options' do
              let(:params) do
                {
                  bin_dir: '/opt/bin',
                  config_dir: '/opt/etc/vault',
                  service_options: '-log-level=info',
                  user: 'root',
                  group: 'admin',
                  num_procs: '5'
                }
              end

              it {
                is_expected.to contain_file('/etc/init.d/vault').
                  with_mode('0755').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^#!/bin/sh}).
                  with_content(%r{export GOMAXPROCS=\${GOMAXPROCS:-5}}).
                  with_content(%r{OPTIONS=\$OPTIONS:-"-log-level=info"}).
                  with_content(%r{exec="/opt/bin/vault"}).
                  with_content(%r{conffile="/opt/etc/vault/config.json"}).
                  with_content(%r{chown root \$logfile \$pidfile})
              }
            end
            context 'does not include systemd reload' do
              it { is_expected.not_to contain_exec('systemd-reload') }
            end
            context 'install through repo with default service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: :undef
                }
              end

              it { is_expected.not_to contain_file('/etc/init.d/vault') }
            end
            context 'install through repo without service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/init.d/vault') }
            end
            context 'install through repo with service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/init.d/vault') }
            end

            context 'install through archive with default service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: :undef
                }
              end

              it { is_expected.to contain_file('/etc/init.d/vault') }
            end
            context 'install through archive without service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/init.d/vault') }
            end
            context 'install through archive with service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/init.d/vault') }
            end
          end
        when 6
          context 'RedHat 6 specific' do
            let :facts do
              facts.merged(service_provider: 'sysv', processorcount: 3)
            end

            context 'includes SysV init script' do
              it {
                is_expected.to contain_file('/etc/init.d/vault').
                  with_mode('0755').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^#!/bin/sh}).
                  with_content(%r{export GOMAXPROCS=\${GOMAXPROCS:-3}}).
                  with_content(%r{OPTIONS=\$OPTIONS:-""}).
                  with_content(%r{exec="/usr/local/bin/vault"}).
                  with_content(%r{conffile="/etc/vault/config.json"}).
                  with_content(%r{chown vault \$logfile \$pidfile})
              }
            end
            context 'service with non-default options' do
              let(:params) do
                {
                  bin_dir: '/opt/bin',
                  config_dir: '/opt/etc/vault',
                  service_options: '-log-level=info',
                  user: 'root',
                  group: 'admin',
                  num_procs: '5'
                }
              end

              it {
                is_expected.to contain_file('/etc/init.d/vault').
                  with_mode('0755').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^#!/bin/sh}).
                  with_content(%r{export GOMAXPROCS=\${GOMAXPROCS:-5}}).
                  with_content(%r{OPTIONS=\$OPTIONS:-"-log-level=info"}).
                  with_content(%r{exec="/opt/bin/vault"}).
                  with_content(%r{conffile="/opt/etc/vault/config.json"}).
                  with_content(%r{chown root \$logfile \$pidfile})
              }
            end
            context 'does not include systemd reload' do
              it { is_expected.not_to contain_exec('systemd-reload') }
            end
            context 'install through repo with default service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: :undef
                }
              end

              it { is_expected.not_to contain_file('/etc/init.d/vault') }
            end
            context 'install through repo without service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/init.d/vault') }
            end
            context 'install through repo with service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/init.d/vault') }
            end

            context 'install through archive with default service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: :undef
                }
              end

              it { is_expected.to contain_file('/etc/init.d/vault') }
            end
            context 'install through archive without service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/init.d/vault') }
            end
            context 'install through archive with service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/init.d/vault') }
            end
          end
        when 7
          context 'RedHat >=7 specific' do
            let :facts do
              facts.merge(service_provider: 'systemd', processorcount: 3)
            end

            context 'includes systemd init script' do
              it {
                is_expected.to contain_file('/etc/systemd/system/vault.service').
                  with_mode('0644').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_notify('Exec[systemd-reload]').
                  with_content(%r{^# vault systemd unit file}).
                  with_content(%r{^User=vault$}).
                  with_content(%r{^Group=vault$}).
                  with_content(%r{Environment=GOMAXPROCS=3}).
                  with_content(%r{^ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json $}).
                  with_content(%r{SecureBits=keep-caps}).
                  with_content(%r{Capabilities=CAP_IPC_LOCK\+ep}).
                  with_content(%r{CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK}).
                  with_content(%r{NoNewPrivileges=yes})
              }
            end
            context 'service with non-default options' do
              let(:params) do
                {
                  bin_dir: '/opt/bin',
                  config_dir: '/opt/etc/vault',
                  service_options: '-log-level=info',
                  user: 'root',
                  group: 'admin',
                  num_procs: 8
                }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/vault.service').
                  with_mode('0644').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_notify('Exec[systemd-reload]').
                  with_content(%r{^# vault systemd unit file}).
                  with_content(%r{^User=root$}).
                  with_content(%r{^Group=admin$}).
                  with_content(%r{Environment=GOMAXPROCS=8}).
                  with_content(%r{^ExecStart=/opt/bin/vault server -config=/opt/etc/vault/config.json -log-level=info$})
              }
            end
            context 'with mlock disabled' do
              let(:params) do
                {
                  disable_mlock: true,
                  storage: {
                    'file' => {
                      'path' => '/data/vault'
                    }
                  },
                  listener: {
                    'tcp' => {
                      'address'     => '127.0.0.1:8200',
                      'tls_disable' => 1
                    }
                  }
                }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/vault.service').
                  with_mode('0644').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_notify('Exec[systemd-reload]').
                  with_content(%r{^# vault systemd unit file}).
                  with_content(%r{^User=vault$}).
                  with_content(%r{^Group=vault$}).
                  with_content(%r{^ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json $}).
                  without_content(%r{SecureBits=keep-caps}).
                  without_content(%r{Capabilities=CAP_IPC_LOCK\+ep}).
                  with_content(%r{CapabilityBoundingSet=CAP_SYSLOG}).
                  with_content(%r{NoNewPrivileges=yes})
              }
            end
            context 'includes systemd reload' do
              it {
                is_expected.to contain_exec('systemd-reload').
                  with_command('systemctl daemon-reload').
                  with_path('/bin:/usr/bin:/sbin:/usr/sbin').
                  with_user('root').
                  with_refreshonly(true)
              }
            end
            context 'install through repo with default service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: :undef
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/vault.service') }
            end
            context 'install through repo without service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/vault.service') }
            end
            context 'install through repo with service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/vault.service') }
            end

            context 'install through archive with default service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: :undef
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/vault.service') }
            end
            context 'install through archive without service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/vault.service') }
            end
            context 'install through archive with service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/vault.service') }
            end
          end
        end
      when 'Debian'
        context 'on Debian OS family' do
          context 'with upstart' do
            let :facts do
              facts.merge(service_provider: 'upstart', processorcount: 3)
            end

            context 'includes init link to upstart-job' do
              it {
                is_expected.to contain_file('/etc/init.d/vault').
                  with_ensure('link').
                  with_target('/lib/init/upstart-job').
                  with_mode('0755')
              }
            end
            context 'contains /etc/init/vault.conf' do
              it {
                is_expected.to contain_file('/etc/init/vault.conf').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# vault Agent \(Upstart unit\)}).
                  with_content(%r{env USER=vault}).
                  with_content(%r{env GROUP=vault}).
                  with_content(/env CONFIG=\/etc\/vault\/config.json/).
                  with_content(/env VAULT=\/usr\/local\/bin\/vault/).
                  with_content(%r{exec start-stop-daemon -u \$USER -g \$GROUP -p \$PID_FILE -x \$VAULT -S -- server -config=\$CONFIG $}).
                  with_content(%r{export GOMAXPROCS=\${GOMAXPROCS:-3}})
              }
            end
          end
          context 'service with modified options and sysv init' do
            let :facts do
              facts.merge(service_provider: 'init')
            end
            let(:params) do
              {
                bin_dir: '/opt/bin',
                config_dir: '/opt/etc/vault',
                service_options: '-log-level=info',
                user: 'root',
                group: 'admin'
              }
            end

            it {
              is_expected.to contain_exec('setcap cap_ipc_lock=+ep /opt/bin/vault').
                with_unless('getcap /opt/bin/vault | grep cap_ipc_lock+ep').
                that_subscribes_to('File[/opt/bin/vault]')
            }
            it { is_expected.to contain_file('/opt/etc/vault/config.json') }

            it { is_expected.to contain_file('/opt/bin/vault').with_mode('0755') }
            it {
              is_expected.to contain_file('/opt/etc/vault').
                with_ensure('directory').
                with_purge('true'). \
                with_recurse('true')
            }
            it { is_expected.to contain_user('root') }
            it { is_expected.to contain_group('admin') }
          end
          context 'install through repo with default service management' do
            let(:params) do
              {
                install_method: 'repo',
                manage_service_file: :undef
              }
            end

            it { is_expected.not_to contain_file('/etc/init.d/vault') }
          end
          context 'install through repo without service management' do
            let(:params) do
              {
                install_method: 'repo',
                manage_service_file: false
              }
            end

            it { is_expected.not_to contain_file('/etc/init.d/vault') }
          end
          context 'install through repo with service management' do
            let(:params) do
              {
                install_method: 'repo',
                manage_service_file: true
              }
            end

            it { is_expected.to contain_file('/etc/init.d/vault') }
          end

          context 'install through archive with default service management' do
            let(:params) do
              {
                install_method: 'archive',
                manage_service_file: :undef
              }
            end

            it { is_expected.to contain_file('/etc/init.d/vault') }
          end
          context 'install through archive without service management' do
            let(:params) do
              {
                install_method: 'archive',
                manage_service_file: false
              }
            end

            it { is_expected.not_to contain_file('/etc/init.d/vault') }
          end
          context 'install through archive with service management' do
            let(:params) do
              {
                install_method: 'archive',
                manage_service_file: true
              }
            end

            it { is_expected.to contain_file('/etc/init.d/vault') }
          end
          context 'on Debian based with systemd' do
            let :facts do
              facts.merge(service_provider: 'systemd', processorcount: 3)
            end

            context 'includes systemd init script' do
              it {
                is_expected.to contain_file('/etc/systemd/system/vault.service').
                  with_mode('0644').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_notify('Exec[systemd-reload]').
                  with_content(%r{^# vault systemd unit file}).
                  with_content(%r{^User=vault$}).
                  with_content(%r{^Group=vault$}).
                  with_content(%r{Environment=GOMAXPROCS=3}).
                  with_content(%r{^ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json $}).
                  with_content(%r{SecureBits=keep-caps}).
                  with_content(%r{Capabilities=CAP_IPC_LOCK\+ep}).
                  with_content(%r{CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK}).
                  with_content(%r{NoNewPrivileges=yes})
              }
            end
            context 'service with non-default options' do
              let(:params) do
                {
                  bin_dir: '/opt/bin',
                  config_dir: '/opt/etc/vault',
                  service_options: '-log-level=info',
                  user: 'root',
                  group: 'admin',
                  num_procs: 8
                }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/vault.service').
                  with_mode('0644').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_notify('Exec[systemd-reload]').
                  with_content(%r{^# vault systemd unit file}).
                  with_content(%r{^User=root$}).
                  with_content(%r{^Group=admin$}).
                  with_content(%r{Environment=GOMAXPROCS=8}).
                  with_content(%r{^ExecStart=/opt/bin/vault server -config=/opt/etc/vault/config.json -log-level=info$})
              }
            end
            context 'with mlock disabled' do
              let(:params) do
                {
                  disable_mlock: true,
                  storage: {
                    'file' => {
                      'path' => '/data/vault'
                    }
                  },
                  listener: {
                    'tcp' => {
                      'address'     => '127.0.0.1:8200',
                      'tls_disable' => 1
                    }
                  }
                }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/vault.service').
                  with_mode('0644').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_notify('Exec[systemd-reload]').
                  with_content(%r{^# vault systemd unit file}).
                  with_content(%r{^User=vault$}).
                  with_content(%r{^Group=vault$}).
                  with_content(%r{^ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json $}).
                  without_content(%r{SecureBits=keep-caps}).
                  without_content(%r{Capabilities=CAP_IPC_LOCK\+ep}).
                  with_content(%r{CapabilityBoundingSet=CAP_SYSLOG}).
                  with_content(%r{NoNewPrivileges=yes})
              }
            end
            context 'includes systemd reload' do
              it {
                is_expected.to contain_exec('systemd-reload').
                  with_command('systemctl daemon-reload').
                  with_path('/bin:/usr/bin:/sbin:/usr/sbin').
                  with_user('root').
                  with_refreshonly(true)
              }
            end
            context 'install through repo with default service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: :undef
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/vault.service') }
            end
            context 'install through repo without service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/vault.service') }
            end
            context 'install through repo with service management' do
              let(:params) do
                {
                  install_method: 'repo',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/vault.service') }
            end

            context 'install through archive with default service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: :undef
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/vault.service') }
            end
            context 'install through archive without service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: false
                }
              end

              it { is_expected.not_to contain_file('/etc/systemd/system/vault.service') }
            end
            context 'install through archive with service management' do
              let(:params) do
                {
                  install_method: 'archive',
                  manage_service_file: true
                }
              end

              it { is_expected.to contain_file('/etc/systemd/system/vault.service') }
            end
          end
        end
      end
    end
  end
end
