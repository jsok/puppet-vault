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

        context 'when not managing user and group' do
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
            with_group('vault')
        }

        context 'vault JSON config' do
          subject { param_value(catalogue, 'File', '/etc/vault/config.json', 'content') }

          it {
            is_expected.to include_json(
              storage: {
                file: {
                  path: '/data/vault'
                }
              }
            )
          }
          it {
            is_expected.to include_json(
              listener: {
                tcp: {
                  address: '127.0.0.1:8200',
                  tls_disable: 1
                }
              }
            )
          }
          it 'excludes unconfigured config options' do
            expect(subject).not_to include_json(
              ha_storage: exist,
              seal: exist,
              disable_cache: exist,
              telemetry: exist,
              default_lease_ttl: exist,
              max_lease_ttl: exist,
              disable_mlock: exist,
              ui: exist,
              api_addr: exist
            )
          end
        end

        it { is_expected.to contain_file('vault_binary').with_mode('0755') }

        context 'when disable mlock' do
          let(:params) do
            {
              disable_mlock: true
            }
          end

          it { is_expected.not_to contain_file_capability('vault_binary_capability') }

          it {
            expect(param_value(catalogue, 'File', '/etc/vault/config.json', 'content')).to include_json(
              disable_mlock: true
            )
          }
        end

        context 'when api address is set' do
          let(:params) do
            {
              api_addr: 'something'
            }
          end


          it {
            expect(param_value(catalogue, 'File', '/etc/vault/config.json', 'content')).to include_json(
              api_addr: 'something'
            )
          }
        end

        context 'when installed from archive' do
          let(:params) { { install_method: 'archive' } }

          it {
            is_expected.to contain_archive('/tmp/vault.zip').
              that_comes_before('File[vault_binary]')
          }

          context 'when installed with default download options' do
            let(:params) do
              super().merge(version: '0.7.0')
            end

            it {
              is_expected.to contain_archive('/tmp/vault.zip').
                with_source('https://releases.hashicorp.com/vault/0.7.0/vault_0.7.0_linux_amd64.zip')
            }
          end

          context 'when specifying a custom download params' do
            let(:params) do
              super().merge(
                version: '0.6.0',
                download_url_base: 'http://my_site.example.com/vault/',
                package_name: 'vaultbinary',
                download_extension: 'tar.gz'
              )
            end

            it {
              is_expected.to contain_archive('/tmp/vault.zip').
                with_source('http://my_site.example.com/vault/0.6.0/vaultbinary_0.6.0_linux_amd64.tar.gz')
            }
          end

          context 'when installed from download url' do
            let(:params) do
              super().merge(download_url: 'http://example.com/vault.zip')
            end

            it {
              is_expected.to contain_archive('/tmp/vault.zip').
                with_source('http://example.com/vault.zip')
            }
          end

          it {
            is_expected.to contain_file_capability('vault_binary_capability').
              with_ensure('present').
              with_capability('cap_ipc_lock=ep').
              that_subscribes_to('File[vault_binary]')
          }

          context 'when not managing file capabilities' do
            let(:params) { { manage_file_capabilities: false } }

            it { is_expected.not_to contain_file_capability('vault_binary_capability') }
          end
        end

        context "When asked not to manage the repo" do
          let(:params) {{
            :manage_repo => false
          }}

          case facts[:os]['family']
          when 'Debian'
            it { should_not contain_apt__source('HashiCorp') }
          when 'RedHat'
            it { should_not contain_yumrepo('HashiCorp') }
          end
        end

        context "When asked to manage the repo but not to install using repo" do
          let(:params) {{
            :install_method => 'archive',
            :manage_repo => true
          }}

          case facts[:os]['family']
          when 'Debian'
            it { should_not contain_apt__source('HashiCorp') }
          when 'RedHat'
            it { should_not contain_yumrepo('HashiCorp') }
          end
        end

        context "When asked to manage the repo and to install as repo" do
          let(:params) {{
            :install_method => 'repo',
            :manage_repo => true
          }}

          case facts[:os]['family']
          when 'Debian'
            it { should contain_apt__source('HashiCorp') }
          when 'RedHat'
            it { should contain_yumrepo('HashiCorp') }
          end
        end

        context 'when installed from package repository' do
          let(:params) do
            {
              install_method: 'repo',
              package_name: 'vault',
              package_ensure: 'installed'
            }
          end

          it { is_expected.to contain_package('vault') }
          it { is_expected.not_to contain_file_capability('vault_binary_capability') }

          context 'when managing file capabilities' do
            let(:params) do
              super().merge(
                manage_file_capabilities: true,
              )
            end

            it { is_expected.to contain_file_capability('vault_binary_capability') }
            it { is_expected.to contain_package('vault').that_notifies(['File_capability[vault_binary_capability]']) }
          end
        end
      end

      context 'when specifying ui to be true' do
        let(:params) do
          {
            enable_ui: true
          }
        end

        it {
          expect(param_value(catalogue, 'File', '/etc/vault/config.json', 'content')).to include_json(
            ui: true
          )
        }
      end

      context 'when specifying config mode' do
        let(:params) do
          {
            config_mode: '0700'
          }
        end

        it { is_expected.to contain_file('/etc/vault/config.json').with_mode('0700') }
      end

      context 'when specifying an array of listeners' do
        let(:params) do
          {
            listener: [
              { 'tcp' => { 'address' => '127.0.0.1:8200' } },
              { 'tcp' => { 'address' => '0.0.0.0:8200' } }
            ]
          }
        end

        it {
          expect(param_value(catalogue, 'File', '/etc/vault/config.json', 'content')).to include_json(
            listener: [
              {
                tcp: {
                  address: '127.0.0.1:8200'
                }
              },
              {
                tcp: {
                  address: '0.0.0.0:8200'
                }
              }
            ]
          )
        }
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

      context 'when specifying manage_storage_dir and file storage backend' do
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

      context 'when specifying manage_storage_dir and raft storage backend' do
        let(:params) do
          {
            manage_storage_dir: true,
            storage: {
              'raft' => {
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

      context 'when specifying manage_config_file = false' do
        let(:params) do
          {
            manage_config_file: false,
          }
        end

        it {
          is_expected.not_to contain_file ('/etc/vault/config.json')
        }
      end

      context 'when ensuring the service is disabled' do
        let(:params) do
          {
            service_enable: false,
            service_ensure: 'stopped'
          }
        end

        it {
          is_expected.to contain_service('vault').
            with_ensure('stopped').
            with_enable(false)
        }
      end

      case facts[:os]['family']
      when 'RedHat'
        case facts[:os]['release']['major'].to_i
        when 2017
          context 'RedHat 7 Amazon Linux specific' do
            let facts do
              facts.merge(service_provider: 'sysv', grocessorcount: 3)
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
            context 'does not include systemd magic' do
              it { is_expected.not_to contain_class('systemd') }
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
            context 'does not include systemd magic' do
              it { is_expected.not_to contain_class('systemd') }
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
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
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
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# vault systemd unit file}).
                  with_content(%r{^User=root$}).
                  with_content(%r{^Group=admin$}).
                  with_content(%r{Environment=GOMAXPROCS=8}).
                  with_content(%r{^ExecStart=/opt/bin/vault server -config=/opt/etc/vault/config.json -log-level=info$})
              }
            end
            context 'with mlock disabled' do
              let(:params) do
                { disable_mlock: true }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/vault.service').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
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
            context 'includes systemd magic' do
              it { is_expected.to contain_class('systemd') }
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
                  with_content(%r{env CONFIG=\/etc\/vault\/config.json}).
                  with_content(%r{env VAULT=\/usr\/local\/bin\/vault}).
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

            it { is_expected.to contain_file('vault_binary').with_path('/opt/bin/vault') }
            it {
              is_expected.to contain_file_capability('vault_binary_capability').
                with_file('/opt/bin/vault')
            }

            it { is_expected.to contain_file('/opt/etc/vault/config.json') }

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
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
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
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
                  with_content(%r{^# vault systemd unit file}).
                  with_content(%r{^User=root$}).
                  with_content(%r{^Group=admin$}).
                  with_content(%r{Environment=GOMAXPROCS=8}).
                  with_content(%r{^ExecStart=/opt/bin/vault server -config=/opt/etc/vault/config.json -log-level=info$})
              }
            end
            context 'with mlock disabled' do
              let(:params) do
                { disable_mlock: true }
              end

              it {
                is_expected.to contain_file('/etc/systemd/system/vault.service').
                  with_mode('0444').
                  with_ensure('file').
                  with_owner('root').
                  with_group('root').
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
            it { is_expected.to contain_systemd__unit_file('vault.service') }

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
      when 'Archlinux'
        context 'defaults to repo install' do
          it { is_expected.to contain_file('vault_binary').with_path('/bin/vault') }
          it { is_expected.not_to contain_file_capability('vault_binary_capability') }
        end
      end
    end
  end
end
