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

Puppet::Type.type(:vault_cert).provide(:openssl, parent: Puppet::Provider::VaultCert) do
  desc 'Manages a certificates from HashiCorp Vault OpenSSL'

  confine kernel: 'Linux'
  commands openssl: 'openssl'

  ##########################
  # public methods inherited from Puppet::Provider
  def exists?
    cert = certificate
    priv_key = private_key
    # Check for the certificate existing at all
    # Check if the given private key matches the given cert
    # Check if the certificate exists in Vault
    # Check if the certificate is expired or not
    # Check if the cert is revoked or not
    (cert && priv_key && cert.check_private_key(priv_key) &&
     check_cert_exists && !check_cert_expiring && !check_cert_revoked)
  end

  # Create a new certificate with the vault API and save it on the filesystem
  def create
    # Revoke the old cert before creating a new one
    revoke_cert if certificate && private_key && check_cert_exists
    new_cert = create_cert
    client_cert_save(new_cert)
  end

  def destroy
    #  Revoke the cert in Vault
    revoke_cert if check_cert_exists
    #  Delete the cert and key off the filesystem
    cert_path = File.join(resource[:cert_dir], resource[:cert_name])
    Pathname.new(cert_path).delete
    priv_key_path = File.join(resource[:priv_key_dir], resource[:priv_key_name])
    Pathname.new(priv_key_path).delete
  end

  #########################
  # private methods

  # Save an openssl cert object into the global cert var
  def certificate
    return @cert unless @cert.nil?

    # Verify that the given directory exists
    unless File.directory?(resource[:cert_dir])
      raise ArgumentError, "Directory not found for: #{resource[:cert_dir]}"
    end

    cert_path = File.join(resource[:cert_dir], resource[:cert_name])
    @cert = if Pathname.new(cert_path).exist?
              file = File.read(cert_path)
              OpenSSL::X509::Certificate.new(file)
            else
              false
            end
  end

  # Save an openssl PKey object into the global priv_key var
  def private_key
    return @priv_key unless @priv_key.nil?

    # Verify that the given directory exists
    unless File.directory?(resource[:priv_key_dir])
      raise ArgumentError, "Directory not found for: #{resource[:priv_key_dir]}"
    end

    priv_key_path = File.join(resource[:priv_key_dir], resource[:priv_key_name])
    @priv_key = if Pathname.new(priv_key_path).exist?
                  file = File.read(priv_key_path)
                  OpenSSL::PKey.read(file, resource[:priv_key_password])
                else
                  false
                end
  end

  def cert_not_after
    certificate.not_after
  end

  def cert_serial_number
    # Read the serial number from the certificate, convert it to base 16 (hex)
    certificate.serial.to_s(16)
  end

  # Save the certificate and private key on the client server
  def client_cert_save(cert)
    # Get the cert path from the directory and name
    # Save the new cert in the certs directory on the client server
    write_file(resource[:cert_dir], resource[:cert_name],
               cert['data']['certificate'])

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
