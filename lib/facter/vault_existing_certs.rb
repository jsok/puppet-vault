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
          common_name = cert.subject.to_a.find { |name, _, _| name == 'CN' }[1]
          certs[cert_path] = {
            'common_name' => common_name,
            'not_after' => cert.not_after.iso8601,
            'not_before' => cert.not_before.iso8601,
            'path' => cert_path,
            'serial' => cert.serial.to_s(16),
            'subject' => cert.subject,
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
        $path = $cert.PSPath.Replace('Microsoft.PowerShell.Security\\Certificate::', 'Cert:\\')
        $cert_data['common_name'] = $cert.SubjectName
        $cert_data['not_after'] = $cert.NotAfter.ToString("o")  # Convert to ISO format
        $cert_data['not_before'] = $cert.NotBefore.ToString("o")
        $cert_data['path'] = $path
        $cert_data['serial'] = $cert.SerialNumber
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
