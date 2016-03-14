require 'spec_helper_acceptance'

describe 'vault class' do

  context 'default parameters' do
    # Using puppet_apply as a helper
    it 'should work idempotently with no errors' do
      pp = <<-EOS
      class { '::vault':
        config_hash => {
          'backend' => {
            'file' => {
              'path' => '/tmp',
            }
          },
          'listener' => {
            'tcp' => {
              'address' => '127.0.0.1:8200',
              'tls_disable' => 1,
            }
          }
        }
      }
      EOS
      # Run it twice and test for idempotency
      apply_manifest(pp, :catch_failures => true)
      apply_manifest(pp, :catch_changes  => true)
    end

    describe user('vault') do
      it { is_expected.to exist }
    end

    describe group('vault') do
      it { is_expected.to exist }
    end

    describe command('getcap /usr/local/bin/vault') do
      its(:exit_status) { is_expected.to eq 0 }
      its(:stdout) { is_expected.to include '/usr/local/bin/vault = cap_ipc_lock+ep' }
    end

    describe file('/usr/local/bin/vault') do
      it { is_expected.to exist }
      it { is_expected.to be_mode 555 }
      it { is_expected.to be_owned_by 'root' }
      it { is_expected.to be_grouped_into 'root' }
    end

    if (fact('osfamily') == 'Debian')
      describe file('/etc/init/vault.conf') do
        it { is_expected.to be_file }
        it { is_expected.to be_mode 444 }
        it { is_expected.to be_owned_by 'root' }
        it { is_expected.to be_grouped_into 'root' }
        its(:content) { is_expected.to include 'env VAULT=/usr/local/bin/vault' }
        its(:content) { is_expected.to include 'env CONFIG=/etc/vault/config.json' }
        its(:content) { is_expected.to include 'env USER=vault' }
        its(:content) { is_expected.to include 'env GROUP=vault' }
        its(:content) { is_expected.to include 'exec start-stop-daemon -u $USER -g $GROUP -p $PID_FILE -x $VAULT -S -- server -config=$CONFIG ' }
        its(:content) { is_expected.to match /export GOMAXPROCS=\${GOMAXPROCS:-\d+}/ }
      end
      describe file('/etc/init.d/vault') do
        it { is_expected.to be_symlink }
        it { is_expected.to be_linked_to '/lib/init/upstart-job' }
      end
    elsif (fact('osfamily') == 'RedHat')
      if (fact('operatingsystemmajrelease') == '6')
        describe file('/etc/init.d/vault') do
          it { is_expected.to be_file }
          it { is_expected.to be_mode 755 }
          it { is_expected.to be_owned_by 'root' }
          it { is_expected.to be_grouped_into 'root' }
          its(:content) { is_expected.to include 'daemon --user vault "{ $exec server -config=$conffile $OPTIONS &>> $logfile & }; echo \$! >| $pidfile"' }
          its(:content) { is_expected.to include 'conffile="/etc/vault/config.json"' }
          its(:content) { is_expected.to include 'exec="/usr/local/bin/vault"' }
          its(:content) { is_expected.to match /export GOMAXPROCS=\${GOMAXPROCS:-\d+}/ }
        end
      else
        describe file('/etc/systemd/system/vault.service') do
          it { is_expected.to be_file }
          it { is_expected.to be_mode 644 }
          it { is_expected.to be_owned_by 'root' }
          it { is_expected.to be_grouped_into 'root' }
          its(:content) { is_expected.to include 'User=vault' }
          its(:content) { is_expected.to include 'Group=vault' }
          its(:content) { is_expected.to include 'ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.json ' }
          its(:content) { is_expected.to match /Environment=GOMAXPROCS=\d+/ }
        end
        describe command('systemctl list-units') do
          its(:stdout) { is_expected.to include 'vault.service' }
        end
      end
    end

    describe file('/etc/vault') do
      it { is_expected.to be_directory }
    end

    describe file('/etc/vault/config.json') do
      it { is_expected.to be_file }
      its(:content) { should include '"address":"127.0.0.1:8200"' }
    end

    describe service('vault') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe port(8200) do
      it { is_expected.to be_listening.on('127.0.0.1').with('tcp') }
    end
  end
end
