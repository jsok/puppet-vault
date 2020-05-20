require 'pathname'
require 'time'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'vault_cert'))

# Steps
# - Verify that the given cert and private key exist and match
# - Check if the cert is revoked or expiring
# - When the cert is going to expire:
#   - Revoke the old cert with the Vault API
#   - Request a new cert with the Vault API
#   - Save the new cert in the given path on the filesystem

Puppet::Type.type(:vault_cert).provide(:openssl) do
  desc 'Manages a certificates from HashiCorp Vault OpenSSL'

  commands openssl: 'openssl'

  ##########################
  # public methods inherited from Puppet::Provider
  def exists?
    cert = certificate_get
    priv_key = private_key_get
    # Check for the certificate existing at all
    # Check if the given private key matches the given cert
    # Check if the certificate is expired or not
    # Check if the cert is revoked or not
    (cert && priv_key && cert.check_private_key(priv_key) &&
     !check_cert_expiring && !check_cert_revoked)
  end

  # Create a new certificate with the vault API and save it on the filesystem
  def create
    # Revoke the old cert before creating a new one
    cert = certificate_get
    priv_key = private_key_get
    revoke_cert if cert && priv_key
    new_cert = create_cert
    client_cert_save(new_cert)
  end

  def destroy
    #  Revoke the cert in Vault
    revoke_cert
    #  Delete the cert and key off the filesystem
    cert_path = File.join(resource[:cert_dir], resource[:cert_name])
    Pathname.new(cert_path).delete
    priv_key_path = File.join(resource[:priv_key_dir], resource[:priv_key_name])
    Pathname.new(priv_key_path).delete
  end

  ###############################
  # public getter/setting methods
  def thumbprint
    return @thumbprint unless @thumbprint.nil?
    cert = certificate
    if cert
      @thumbprint = OpenSSL::Digest::SHA1.new(cert.to_der).to_s.upcase
    end
    @thumbprint
  end

  #########################
  # private methods

  # Check whether the time left on the cert is less than the ttl
  # Return true if the cert is about to expire
  def check_cert_expiring
    cert = certificate_get
    expire_date = cert.not_after

    now = Time.now
    # Calculate the difference in time (seconds) and convert to hours
    hours_until_expired = (expire_date - now) / 60 / 60
    hours_until_expired < resource[:regenerate_ttl]
  end

  # Save an openssl cert object into the global cert var
  def certificate_get
    return @cert unless @cert.nil?
    cert_path = File.join(resource[:cert_dir], resource[:cert_name])
    @cert = if Pathname.new(cert_path).exist?
              file = File.read(cert_path)
              OpenSSL::X509::Certificate.new(file)
            else
              false
            end
  end

  # Save an openssl PKey object into the global priv_key var
  def private_key_get
    return @priv_key unless @priv_key.nil?
    priv_key_path = File.join(resource[:priv_key_dir], resource[:priv_key_name])
    @priv_key = if Pathname.new(priv_key_path).exist?
                  file = File.read(priv_key_path)
                  OpenSSL::PKey.read(file, resource[:key_password])
                else
                  false
                end
  end

  # Read the serial number from the certificate, convert it to base 16, and add colons
  def cert_serial_get
    cert = certificate_get
    # Convert the base 10 serial number from the openssl cert to hexadecimal
    serial_number = cert.serial.to_s(16)
    # Add a colon every 2 characters to the returned serial number
    serial_number.scan(%r{\w{2}}).join(':')
  end

  # Save the certificate and private key on the client server
  def client_cert_save(cert)
    # Get the cert path from the directory and name
    # Save the new cert in the certs directory on the client server
    write_file(resource[:cert_dir], resource[:cert_name],
               cert['data']['certificate'])

    # compute thumbprint of the cert
    x509_cert = OpenSSL::X509::Certificate.new(file)
    @thumbprint = OpenSSL::Digest::SHA1.new(x509_cert.to_der).to_s.upcase

    # Get the private key path from the directory and name
    # Save the new private key in the tls directory on the client
    write_file(resource[:priv_key_dir], resource[:priv_key_name],
               cert['data']['private_key'])

    # NOTE: we specifically do NOT handle file owners + modes in here
    # if you need that functionality, please use the vault::cert resource
  end

  # Write data to a file
  def write_file(dir, name, data)
    path = File.join(dir, name)
    File.open(path, 'w') do |f|
      f.write(data)
    end
    path
  end
end
