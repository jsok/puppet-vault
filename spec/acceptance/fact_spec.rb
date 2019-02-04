require "spec_helper"

describe "Facter::Util::Fact" do
  before {
    Facter.clear
    allow(Facter.fact(:kernel)).to receive(:value).and_return("Linux")
  }

  describe "vault_version" do
    it do
      allow(Facter::Util::Resolution).to receive(:exec).with("vault --version").
        and_return("Vault v1.0.2 ('37a1dc9c477c1c68c022d2084550f25bf20cac33')")
      expect(Facter.fact(:vault_version).value).to eql("1.0.2")
    end
  end
end
