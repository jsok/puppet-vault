require 'pathname'
require 'time'
require 'ruby-pwsh'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'vault_cert'))

# Steps
# - Verify that the given cert and private key exist and match
# - Check if the cert is revoked or expiring
# - When the cert is going to expire:
#   - Revoke the old cert with the Vault API
#   - Request a new cert with the Vault API
#   - Save the new cert in the given path on the filesystem

Puppet::Type.type(:vault_cert).provide(:powershell, parent: Puppet::Provider::VaultCert) do
  desc 'Manages a certificates from HashiCorp Vault OpenSSL'

  commands powershell: 'powershell.exe'

  ##########################
  # public methods inherited from Puppet::Provider
  def exists?
    # Check for the certificate existing at all
    # Check if the certificate is expired or not
    # Check if the cert is revoked or not
    certificate && !check_cert_expiring && !check_cert_revoked
  end

  # Create a new certificate with the vault API and save it on the filesystem
  def create
    # Revoke the old cert before creating a new one
    revoke_cert if certificate
    new_cert = create_cert
    client_cert_save(new_cert)
  end

  def destroy
    # Revoke the cert in Vault
    revoke_cert

    # Remove certificate from certificate store
    cmd = <<-EOF
    $cert = Get-Item '#{resource[:cert_dir]}\*' | Where-object { $_.Subject -eq '#{resource[:common_name]}' }
    $cert | Remove-Item
    EOF
    res = ps(cmd)
    Puppet.info("Deleted cert exitcode: #{res[:exitcode]} ")
    Puppet.info("Deleted cert stdout: #{res[:stdout]} ")
    Puppet.info("Deleted cert stderr: #{res[:stderr]} ")
  end

  #########################
  # private methods
  def ps(cmd)
    @ps ||= Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
    # need to use [:stdout] from result
    @ps.execute(cmd)
  end

  # Save an openssl cert object into the global cert var
  def certificate
    return @cert unless @cert.nil?
    cmd = <<-EOF
    $cert = Get-Item '#{resource[:cert_dir]}\*' | Where-object { $_.Subject -eq '#{resource[:common_name]}' }
    $data = @{
      'not_after' = $cert.NotAfter.ToString("o");  # Convert to ISO format
      'not_before' = $cert.NotBefore.ToString("o");
      'serial' = $cert.SerialNumber;
    }
    $data | ConvertTo-Json
    EOF
    res = ps(cmd)
    @cert = if res[:exitcode].zero?
              JSON.parse(res[:stdout])
            else
              false
            end
  end

  ##########################
  # not converted

  # Check whether the time left on the cert is less than the ttl
  # Return true if the cert is about to expire
  def check_cert_expiring
    expire_date = Time.parse(certificate['not_after'])
    # Calculate the difference in time (seconds) and convert to hours
    hours_until_expired = (expire_date - Time.now) / 60 / 60
    hours_until_expired < resource[:regenerate_ttl]
  end

  # Read the serial number from the certificate, convert it to base 16, and add colons
  def cert_serial_get
    # Convert the base 10 serial number from the openssl cert to hexadecimal
    serial_number = certificate['serial'].to_s(16)
    # Add a colon every 2 characters to the returned serial number
    serial_number.scan(%r{\w{2}}).join(':')
  end

  # Save the certificate and private key on the client server
  def client_cert_save(cert)
    key    = OpenSSL::PKey.read(cert['data']['private_key'])
    cert   = OpenSSL::X509::Certificate.new(cert['data']['certificate'])
    name   = nil # not sure whether this is allowed
    pkcs12 = OpenSSL::PKCS12.create(resource[:key_password], name, key, cert)
    pkcs12_der = pkcs12.to_der

    file = Tempfile.new(resource[:cert_name])
    begin
      file.write(pkcs12_der)
      cmd = "Import-Certificate -FilePath '#{file.path}' '#{resource[:cert_dir]}'"
      res = ps(cmd)
      Puppet.info("Imported cert exitcode: #{res[:exitcode]} ")
      Puppet.info("Imported cert stdout: #{res[:stdout]} ")
      Puppet.info("Imported cert stderr: #{res[:stderr]} ")
    ensure
      file.close
      file.unlink
    end
  end
end
