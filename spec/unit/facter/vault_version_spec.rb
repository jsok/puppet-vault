require "spec_helper"

describe "Vault Version Specs" do
    context 'when Vault is installed' do
        let(:vault_version) { "Vault v1.0.2 ('37a1dc9c477c1c68c022d2084550f25bf20cac33')" }
        it 'should return vault version 1.0.2' do
            allow(Facter::Util::Resolution).to receive(:exec).with('vault --version').and_return(vault_version)
            expect(Facter.fact(:vault_version).value).to eql("1.0.2")
        end
    end
end
