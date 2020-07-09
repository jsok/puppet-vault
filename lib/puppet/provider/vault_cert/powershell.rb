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
    # false if the user passed in cert and private key data, this will force
    # a call to create()
    if resource[:cert] && resource[:priv_key]
      Puppet.info('exists? - cert and priv_key were specified')
      return false
    else
      Puppet.info('exists? - cert and priv_key were NOT specified')
    end
    # Check for the certificate existing at all
    # Check if the certificate is expired or not
    # Check if the cert is revoked or not
    certificate && !check_cert_expiring && !check_cert_revoked
  end

  # Create a new certificate with the vault API and save it on the filesystem
  def create
    Puppet.info('creating')
    # Revoke the old cert before creating a new one
    revoke_cert if certificate

    # TODO remove / delete existing cert

    if resource[:cert] && resource[:priv_key]
      Puppet.info('creating from exising cert')
      # user passed in the certificate data for us, use this
      client_cert_save(resource[:cert], resource[:priv_key])
    else
      # create a new cert via Vault API
      Puppet.info('creating from new cert from vault')
      new_cert = create_cert
      client_cert_save(new_cert['data']['certificate'], new_cert['data']['private_key'])
    end
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
    Puppet.debug("Running command: #{cmd}")
    # need to use [:stdout] from result
    @ps.execute(cmd)
  end

  # Save an openssl cert object into the global cert var
  def certificate
    return @cert unless @cert.nil?
    cmd = <<-EOF
    $cert = Get-Item '#{resource[:cert_dir]}\*' | Where-object { $_.Subject -eq 'CN=#{resource[:common_name]}' }
    if ($cert) {
      # don't put this in one big expression, this way powershell throws an error on the specific
      # line that is having a problem, not the beginning of the expression
      $data = @{}
      $data['not_after'] = $cert.NotAfter.ToString("o")  # Convert to ISO format
      $data['not_before'] = $cert.NotBefore.ToString("o")
      $data['serial_number'] = $cert.SerialNumber
      $data['thumbprint'] = $cert.Thumbprint
    } else {
      $data = $null
    }
    $data | ConvertTo-Json
    EOF
    res = ps(cmd)
    Puppet.info('parsing cert json')
    Puppet.info("got output: #{res[:stdout]}")
    # add to check for truthy stdout because, if the cert doesn't exist the output
    # could be nil / empty string
    @cert = if res[:exitcode].zero? && res[:stdout]
              JSON.parse(res[:stdout])
            else
              false
            end
    Puppet.info("finished getting cert: #{@cert}")
    @cert
  end

  ##########################
  # not converted

  # Check whether the time left on the cert is less than the ttl
  # Return true if the cert is about to expire
  def check_cert_expiring
    Puppet.info('checking cert expiring')
    expire_date = Time.parse(certificate['not_after'])
    # Calculate the difference in time (seconds) and convert to hours
    hours_until_expired = (expire_date - Time.now) / 60 / 60
    hours_until_expired < resource[:regenerate_ttl]
  end

  # Read the serial number from the certificate, convert it to base 16, and add colons
  def cert_serial_get
    Puppet.info('getting cert serial')
    # Convert the base 10 serial number from the openssl cert to hexadecimal
    serial_number = certificate['serial_number'].to_s(16)
    # Add a colon every 2 characters to the returned serial number
    serial_number.scan(%r{\w{2}}).join(':')
  end

  # Save the certificate and private key on the client server
  def client_cert_save(cert, priv_key)
    Puppet.info('saving cert')
    key       = OpenSSL::PKey.read(priv_key)
    x509_cert = OpenSSL::X509::Certificate.new(cert)
    name      = resource[:cert_name]
    # compute thumbprint of the cert
    # thumbprint = OpenSSL::Digest::SHA1.new(x509_cert.to_der).to_s.upcase

    if resource[:priv_key_password] && resource[:priv_key_password].size >= 4
      password = resource[:priv_key_password]
    else
      require 'securerandom'
      password = SecureRandom.alphanumeric(16)
    end
    pkcs12 = OpenSSL::PKCS12.create(password, name, key, x509_cert)
    pkcs12_der = pkcs12.to_der

    Puppet.info("cert data: #{cert}")
    Puppet.info("key data: #{priv_key}")
    Puppet.info("Der data: #{pkcs12_der} ")

    file = Tempfile.new(resource[:cert_name])
    begin
      file.binmode
      file.write(pkcs12_der)
      # have to close file before Import-PfxCertificate can open it
      file.close

      cmd = <<-EOF
      $password = ConvertTo-SecureString -String '#{password}' -Force -AsPlainText
      Import-PfxCertificate -FilePath '#{file.path}' -CertStoreLocation '#{resource[:cert_dir]}' -Password $password
      EOF
      res = ps(cmd)
      Puppet.info("Imported cert exitcode: #{res[:exitcode]} ")
      Puppet.info("Imported cert stdout: #{res[:stdout]} ")
      Puppet.info("Imported cert stderr: #{res[:stderr]} ")
    ensure
      file.close
      file.unlink
    end
    # File.open(File.join('c:\\', resource[:cert_name]), 'wb') do |file|
    #   file.write(pkcs12_der)
    #   cmd = <<-EOF
    #   $password = ConvertTo-SecureString -String '#{password}' -Force -AsPlainText
    #   Import-PfxCertificate -FilePath '#{file.path}' -CertStoreLocation '#{resource[:cert_dir]}' -Password $password
    #   EOF
    #   res = ps(cmd)
    #   Puppet.info("Imported cert exitcode: #{res[:exitcode]} ")
    #   Puppet.info("Imported cert stdout: #{res[:stdout]} ")
    #   Puppet.info("Imported cert stderr: #{res[:stderr]} ")
    #   raise "Error importing cert: #{res[:stderr]}" unless res[:exitcode].zero?
    # end
  end
end
