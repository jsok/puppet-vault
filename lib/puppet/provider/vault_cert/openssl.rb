require 'pathname'
require 'time'

# prepreqs
# - assume a certificate on the filesystem
#   - rick, help with an openssl to generate this for John
#   - potentially with a short expiration time, or one that is already
#     expired
#
# Steps
# - use Ruby OpenSSL if we can, otherwsie default to the `openssl` command
# - Convert this resource over to detect when a cert is going to expire
#   - put this in the exists? function
# - When the cert is going to expire, reach out to Vault and request a
#   new one.
#   - download the cert and put it on the filesystem
#   - probably need to write down the cert ID
# - Check the CRL or the cert itself
#
# References:
# - https://github.com/camptocamp/puppet-openssl/blob/master/lib/puppet/provider/x509_cert/openssl.rb
# - https://github.com/voxpupuli/puppet-grafana/blob/master/lib/puppet/provider/grafana_datasource/grafana.rb
# - https://github.com/voxpupuli/puppet-grafana/blob/master/lib/puppet/provider/grafana.rb
# - https://github.com/StackStorm/puppet-st2/blob/master/lib/puppet/provider/st2_pack/default.rb
# 
# Blog:
# - http://garylarizza.com/blog/2013/11/25/fun-with-providers/
# - http://garylarizza.com/blog/2013/11/26/fun-with-providers-part-2/
# - http://garylarizza.com/blog/2013/12/15/seriously-what-is-this-provider-doing/
#

Puppet::Type.type(:vault_cert).provide(:openssl) do
  desc 'Manages a certificates from HashiCorp Vault OpenSSL'

  commands openssl: 'openssl'

  def self.get_private_key(private_key_path)
    file = File.read(private_key_path)
    OpenSSL::PKey::RSA.new(file)
  end

  def self.get_certificate(cert_path)
    file = File.read(cert_path)
    OpenSSL::X509::Certificate.new(file)
  end

  #def self.check_private_key(resource)
  #  cert = OpenSSL::X509::Certificate.new(File.read(resource[:path]))
  #  priv = private_key(resource)
  #  cert.check_private_key(priv)
  #end

  def cert_expiring(cert, ttl_hours)
    expire_date = cert.not_after
    now = Time.now
    # Calculate the difference in time (seconds) and convert to hours
    hours_until_expired = (expire_date - now) / 60 / 60

    #info(hours_until_expired)
    puts(hours_until_expired)
    Puppet.info("Time until expired: #{hours_until_expired.to_s}")
  end

  def exists?
    # TODO
    #  - check for the certificate existing at all
    #  - check for the certificate being expired or not
    #    - if expired, returned false, so we create a new one
    #  - check if cert is revoked (if we want to get crazy)
    #    - if we have the cert ID, we can ask Vault for this
    
    if Pathname.new(resource[:path]).exist?
      cert = get_certificate(resource[:path])
      priv_key = get_private_key(resource[:private_key])
      if !cert.check_private_key(priv_key)
        return false
      end
      cert_expiring(cert, resource[:ttl_hours])
      #unless self.class.old_cert_is_equal(resource)
      #  return false
      #end
      true
    else
      false
    end
  end

  def create
    # TODO
    #  - this is where we'll go to Vault and request a new cert
    #  - drop the cert on the filesystem
    # This is where we want to use the Grafana resource reference
    cert_expiring(cert, resource[:ttl_hours])
  end

  def destroy
    # TODO
    #  - delete the cert off the filesystem
    #  - revoke the cert in Vault
    Pathname.new(resource[:path]).delete
  end
end
