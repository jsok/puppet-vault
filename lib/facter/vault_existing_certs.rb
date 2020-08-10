Facter.add(:vault_existing_certs) do
  confine kernel: ['FreeBSD', 'Linux', 'OpenBSD']

  setcode do
    require 'openssl'
    require 'pathname'
    require 'time'

    # Local the certificate directories
    #  '/etc/pki/tls/certs' = RHEL
    #  '/etc/ssl/certs'     = Debian/Ubuntu
    search_path_list = ['/etc/pki/tls/certs', '/etc/ssl/certs']
    certs = {}

    # for each directory, read the cert files and return info about them
    search_path_list.each do |search|
      search_path = Pathname.new(search)
      next unless search_path.directory?

      search_path.children.select(&:file?).each do |path|
        next unless ['.pem', '.crt', 'cer', '.p7b', '.p7s', '.p7c', '.key'].include?(path.extname)
        begin
          cert_path = path.realpath.to_s
          next if certs.key?(cert_path) # avoid reading the same cert over/over
          cert = OpenSSL::X509::Certificate.new(File.new(cert_path).read)
          cert_extension = File.extname(cert_path)
          cert_name = File.basename(cert_path, cert_extension)
          cn_attr = cert.subject.to_a.find { |name, _, _| name == 'CN' }
          # some certificates might not have a Common Name (CN) attribute in their
          # subject, so check for this and return an empty string in this case
          # in this case the cn_attr will be nil
          common_name_utf8 = (cn_attr && cn_attr.length > 2) ? cn_attr[1] : ''
          # handle translation of unicode characters because standard JSON
          # library struggles with unicode (sorry, no my fault!)
          common_name = common_name_utf8.encode('ASCII',
                                                invalid: :replace,
                                                undef: :replace,
                                                replace: "_")
          certs[cert_path] = {
            'common_name' => common_name,
            'cert_name' => cert_name,
            'not_after' => cert.not_after.iso8601,
            'not_before' => cert.not_before.iso8601,
            'path' => cert_path,
            'serial_number' => cert.serial.to_s(16),
            'subject' => cert.subject.to_s,
            # do not compute thumbprint on Linux because it's expensive
            # only needed on Windows anyways
            # 'thumbprint' => OpenSSL::Digest::SHA1.new(x509_cert.to_der).to_s.upcase,
          }
        rescue OpenSSL::X509::CertificateError
          next # fake out rubocop into thinking we've handled the exception
        end
      end
    end
    certs
  end
end

Facter.add(:vault_existing_certs) do
  confine kernel: 'windows'

  setcode do
    require 'ruby-pwsh'
    ps = Pwsh::Manager.instance(Pwsh::Manager.powershell_path, Pwsh::Manager.powershell_args)
    cmd = <<-EOF
    $cert_list = @(Get-Item Cert:\\LocalMachine\\My\\*)
    if ($cert_list) {
      # don't put this in one big expression, this way powershell throws an error on the specific
      # line that is having a problem, not the beginning of the expression
      $data = @{}
      foreach ($cert in $cert_list) {
        $cert_data = @{}
        $path = $cert.PSPath.Replace('Microsoft.PowerShe.Security\\Certificate::', 'Cert:\\')
        $cert_data['common_name'] = $cert.SubjectName.Name -replace '^CN=', ''
        $cert_data['cert_name'] = $cert.FriendlyName
        $cert_data['not_after'] = $cert.NotAfter.ToString("o")  # Convert to ISO format
        $cert_data['not_before'] = $cert.NotBefore.ToString("o")
        $cert_data['path'] = $path
        $cert_data['serial_number'] = $cert.SerialNumber
        $cert_data['subject'] = $cert.Subject
        $cert_data['thumbprint'] = $cert.Thumbprint
        $data[$path] = $cert_data
      }
    } else {
      $data = $null
    }
    $data | ConvertTo-Json
    EOF
    res = ps.execute(cmd)
    JSON.parse(res[:stdout])
  end
end
