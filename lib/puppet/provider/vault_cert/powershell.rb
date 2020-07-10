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
    Puppet.info("exists? - resource: #{resource}")
    Puppet.info("exists? - cert: #{resource[:cert]}")
    Puppet.info("exists? - priv_key: #{resource[:priv_key]}")
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
    # certificate && !check_cert_expiring && !check_cert_revoked
    if certificate_list
      # if we're trying to delete the cert, we simply need to check if there are certs
      # at all, so that all of them are deleted, no sense in checking if exisintg certs
      # are expiring/revoked when deleting certs,
      return !certificate_list.empty? if resource[:ensure] == :absent

      # if we have > 1 cert, we need to cleanup the old ones... so
      # if we are trying to create a cert (ensure: present), we need to say the cert
      # doesn't exist so that create() is called and the old ones are destroyed
      if certificate_list.size > 1
        return false
      end

      Puppet.info('exists? - certificate exists')
      if !check_cert_expiring_list
        Puppet.info('exists? - certificate IS NOT expiring')
        if !check_cert_revoked_list
          Puppet.info('exists? - certificate IS NOT revoked')
          Puppet.info('exists? - yes, this thing really exists')
          return true
        else
          Puppet.info('exists? - certificate IS revoked')
        end
      else
        Puppet.info('exists? - certificate IS expiring')
      end
    else
      Puppet.info('exists? - certificate doesnt exist')
    end
    Puppet.info('exists? - no, this thing doesnt exist')
    false
  end

  # Create a new certificate with the vault API and save it on the filesystem
  def create
    Puppet.info('creating')

    # don't check priv_key here because priv_key isnt looked up via facts
    if resource[:cert]
      Puppet.info('creating from exising cert')
      # user passed in the certificate data for us, use this
      cert = resource[:cert]
      priv_key = resource[:priv_key]
    else
      # create a new cert via Vault API
      Puppet.info('creating from new cert from vault')
      new_cert = create_cert
      cert = new_cert['data']['certificate']
      priv_key = new_cert['data']['private_key']
    end

    thumbprint = nil
    serial_number = nil
    if cert
      Puppet.info("computed new cert serial: #{serial_number}")
      sn_th = PuppetX::Encore::Vault::Util.cert_sn_thumbprint(cert)
      thumbprint = sn_th[:thumbprint]
      serial_number = sn_th[:serial_number]
    end

    # if there is an existing cert with this common name that doesn't match our
    # thumbprint/serial, then destroy the old one, remove from trust store and create a new one
    if certificate_list && !certificate_list.empty? &&
       (certificate_list.size > 1 ||
        (certificate_list.first['thumbprint'] != thumbprint ||
         certificate_list.first['serial_number'] != serial_number))
      Puppet.info("A certificate with the same common name exists, but doesn't match our thumbprint and serial number, we're going to delete these old one(s)")
      # Revoke the old cert and remove it from the trust store
      destroy
    end

    # can only save/import the certificate into the cert store if we have
    # the cert and priv_key
    # this is important on a puppet run where we've read the existing certificate from
    # facts, but not the private key (private key isn't exposed in facts)
    # this way we can check on exist certs without overwriting them
    if cert
      if priv_key
        Puppet.info('saving client cert to cert store')
        client_cert_save(cert, priv_key)
      else
        Puppet.info('not saving client cert because only have cert and not priv key')
      end
    else
      Puppet.info('not saving client cert because cert and priv_key are both nil')
    end
  end

  def destroy
    Puppet.info('Destroying')
    # Revoke the cert in Vault
    revoke_cert_list

    # Remove certificate from certificate store
    cmd = <<-EOF
    $cert_list = Get-Item '#{resource[:cert_dir]}\\*' | Where-object { $_.Subject -eq 'CN=#{resource[:common_name]}' }
    $cert_list | Remove-Item
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
  def certificate_list
    return @cert_list unless @cert_list.nil?
    cmd = <<-EOF
    $certs_list = Get-Item '#{resource[:cert_dir]}\\*' | Where-object { $_.Subject -eq 'CN=#{resource[:common_name]}' }
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
    } else {
      $data = $null
    }
    $data | ConvertTo-Json
    EOF
    res = ps(cmd)
    Puppet.info('parsing cert json')
    Puppet.info("got output: #{res}")
    # add to check for truthy stdout because, if the cert doesn't exist the output
    # could be nil / empty string
    @cert_list = if res[:exitcode].zero? && res[:stdout]
                   JSON.parse(res[:stdout])
                 else
                   false
                 end
    Puppet.info("finished getting cert list: #{@cert_list}")
    @cert_list
  end

  def revoke_cert_list
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
    Puppet.info('saving cert')
    key       = OpenSSL::PKey.read(priv_key)
    x509_cert = OpenSSL::X509::Certificate.new(cert)
    name      = resource[:cert_name]
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
  end
end
