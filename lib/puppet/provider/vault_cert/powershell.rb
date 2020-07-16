require 'pathname'
require 'time'
require 'ruby-pwsh'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'vault_cert'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'encore', 'vault', 'util'))

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
    return false if resource[:cert] && resource[:priv_key]

    # if we're trying to delete the cert, we simply need to check if there are certs
    # at all, so that all of them are deleted, no sense in checking if exisintg certs
    # are expiring/revoked when deleting certs,
    return !certificate_list.empty? if certificate_list && resource[:ensure] == :absent

    # Check for the certificate existing at all
    # if we have > 1 cert, we need to cleanup "extra" ones by returning (false) so that
    #   create is called, so only return true if we have exactly one cert
    # Check if the certificate is expired or not
    # Check if the cert is revoked or not
    (certificate_list && certificate_list.size == 1 &&
     !check_cert_expiring_list && !check_cert_revoked_list)
  end

  # Create a new certificate with the vault API and save it on the filesystem
  def create
    Puppet.debug('creating')

    # don't check priv_key here because priv_key isnt looked up via facts
    if resource[:cert]
      Puppet.debug('creating from exising cert')
      # user passed in the certificate data for us, use this
      cert = resource[:cert]
      priv_key = resource[:priv_key]
    else
      # create a new cert via Vault API
      Puppet.debug('creating from new cert from vault')
      new_cert = create_cert
      cert = new_cert['data']['certificate']
      priv_key = new_cert['data']['private_key']
    end

    thumbprint = nil
    serial_number = nil
    if cert
      Puppet.debug("computed new cert serial: #{serial_number}")
      details = PuppetX::Encore::Vault::Util.cert_details(cert)
      thumbprint = details[:thumbprint]
      serial_number = details[:serial_number]
    end

    # if there is an existing cert with this cert_name(friendly name) that doesn't match our
    # thumbprint/serial, then destroy the old one, remove from trust store and create a new one
    if certificate_list && !certificate_list.empty? &&
       (certificate_list.size > 1 ||
        (certificate_list.first['thumbprint'] != thumbprint ||
         certificate_list.first['serial_number'] != serial_number))
      Puppet.debug("A certificate with the same cert name (FriendlyName) exists, but doesn't match our thumbprint and serial number, we're going to delete these old one(s)")
      # Note: we _could_ try to keep some certs here, but this adds a ton of additional
      # complexity, like... which ones should we keep, what if the ones we're trying to
      # keep is expired, revoked, etc. Easiest thing is to just revoke and remove all
      # of the certs and make a new one.
      destroy

      # if we just destroyed all of the certs on the system, we need to make a new one
      # unless the cert and priv_key were given above
      unless cert && priv_key
        new_cert = create_cert
        cert = new_cert['data']['certificate']
        priv_key = new_cert['data']['private_key']
      end
    end

    # can only save/import the certificate into the cert store if we have
    # the cert and priv_key
    # this is important on a puppet run where we've read the existing certificate from
    # facts, but not the private key (private key isn't exposed in facts)
    # this way we can check on exist certs without overwriting them
    if cert
      if priv_key
        Puppet.debug('saving client cert to cert store')
        client_cert_save(cert, priv_key)
      else
        Puppet.debug('not saving client cert because only have cert and not priv key')
      end
    else
      Puppet.debug('not saving client cert because cert and priv_key are both nil')
    end
  end

  def destroy
    Puppet.debug('Destroying')
    # Revoke the cert in Vault
    revoke_cert_list

    # Remove certificate from certificate store
    cmd = <<-EOF
    $cert_list = Get-Item '#{resource[:cert_dir]}\\*' | Where-object { $_.FriendlyName -eq '#{resource[:cert_name]}' }
    $cert_list | Remove-Item
    EOF
    res = ps(cmd)
    Puppet.debug("Deleted cert exitcode: #{res[:exitcode]} ")
    Puppet.debug("Deleted cert stdout: #{res[:stdout]} ")
    Puppet.debug("Deleted cert stderr: #{res[:stderr]} ")
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
  def certificate_list
    return @cert_list unless @cert_list.nil?
    cmd = <<-EOF
    $certs_list = Get-Item '#{resource[:cert_dir]}\\*' | Where-object { $_.FriendlyName -eq '#{resource[:cert_name]}' }
    if ($certs_list) {
      $data = @()
      foreach ($cert in $certs_list) {
        # don't put this in one big expression, this way powershell throws an error on the specific
        # line that is having a problem, not the beginning of the expression
        $data += @{
          'not_after'= $cert.NotAfter.ToString("o");  # Convert to ISO format
          'not_before' = $cert.NotBefore.ToString("o");
          'serial_number' = $cert.SerialNumber;
          'thumbprint' = $cert.Thumbprint;
        }
      }
      # powershell is dumb and will "unbox" a single-element array and return just the elemtn
      # we really want an array though... thanks PowerShell... 
      ConvertTo-Json @($data)
    }
    EOF
    res = ps(cmd)
    Puppet.debug('parsing cert json')
    Puppet.debug("got output: #{res}")
    # add to check for truthy stdout because, if the cert doesn't exist the output
    # could be nil / empty string
    @cert_list = if res[:exitcode].zero? && res[:stdout]
                   JSON.parse(res[:stdout])
                 else
                   false
                 end
    Puppet.debug("finished getting cert list: #{@cert_list}")
    @cert_list
  end

  def revoke_cert_list
    Puppet.debug('revoking cert list')
    certificate_list.each { |cert| revoke_cert(serial_number: cert_serial_number(cert)) }
  end

  def check_cert_revoked_list
    certificate_list.any? { |cert| check_cert_revoked(serial_number: cert_serial_number(cert)) }
  end

  def check_cert_expiring_list
    certificate_list.any? { |cert| check_cert_expiring(not_after: cert_not_after(cert)) }
  end

  def cert_not_after(cert)
    Time.parse(cert['not_after'])
  end

  def cert_serial_number(cert)
    # serial_number is already a hex string (from PowerShell)
    cert['serial_number']
  end

  # Save the certificate and private key on the client server
  def client_cert_save(cert, priv_key)
    Puppet.debug('saving cert')
    key       = OpenSSL::PKey.read(priv_key)
    x509_cert = OpenSSL::X509::Certificate.new(cert)
    name      = resource[:cert_name]
    # PKCS12 private keys must be at least 4 characaters
    if resource[:priv_key_password] && resource[:priv_key_password].size >= 4
      password = resource[:priv_key_password]
    else
      # PKCS12 private keys require a password, so generate a random 16 character one
      Puppet.debug("vault_cert[#{resource[:cert_name]}] was either not given a private key password or it was less than 4 characters, automatically generating a private key password for you")
      require 'securerandom'
      password = SecureRandom.alphanumeric(16)
    end
    pkcs12 = OpenSSL::PKCS12.create(password, name, key, x509_cert)
    pkcs12_der = pkcs12.to_der

    Puppet.debug("cert data: #{cert}")

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
      Puppet.debug("Imported cert exitcode: #{res[:exitcode]} ")
      Puppet.debug("Imported cert stdout: #{res[:stdout]} ")
      Puppet.debug("Imported cert stderr: #{res[:stderr]} ")
    ensure
      file.close
      file.unlink
    end
  end
end
