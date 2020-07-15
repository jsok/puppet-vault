require 'puppet_x'

# Encore module
module PuppetX::Encore; end

module PuppetX::Encore::Vault
  # Utilities for vault and certificates
  class Util
    def self.cert_details(cert)
      x509_cert = OpenSSL::X509::Certificate.new(cert)
      {
        thumbprint: OpenSSL::Digest::SHA1.new(x509_cert.to_der).to_s.upcase,
        serial_number: x509_cert.serial.to_s(16),
        common_name: x509_cert.subject.to_a.find { |name, _, _| name == 'CN' }[1],
        not_after: x509_cert.not_after.iso8601,
        not_before: x509_cert.not_before.iso8601,
        subject: x509_cert.subject.to_s,
      }
    end

    # Check whether the time left on the cert is less than the ttl
    # Return true if the cert is about to expire
    def self.check_expiring(not_after, regenerate_ttl)
      Puppet.debug('checking cert expiring')
      # Calculate the difference in time (seconds) and convert to hours
      hours_until_expired = (not_after - Time.now) / 60 / 60
      expiring = hours_until_expired < regenerate_ttl
      Puppet.debug("check cert is expiring: #{hours_until_expired} < #{regenerate_ttl} = #{expiring}")
      expiring
    end
  end
end
