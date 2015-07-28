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

    describe file('/usr/local/bin/vault') do
      it { is_expected.to exist }
    end

    describe service('vault') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
