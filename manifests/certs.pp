# Generate certificates and save their details up front
class vault::certs (
  String $api_server,
  String $api_token,
  String $secret_role,
  # key = common_name
  # value = certificate options/details
  Hash[String, Struct[{
    serial_number => Optional[String],
    alt_names => Optional[String],
    ip_sans => Optional[String],
  }]] $certs,
  # API options
  Optional[Integer] $api_port       = undef,
  Optional[String] $api_scheme      = undef,
  Optional[String] $cert_ttl        = undef,
  Optional[String] $cert_dir        = undef,
  String $cert_group                = 'root',
  String $cert_owner                = 'root',
  Stdlib::Filemode $cert_mode       = '0644',
  Optional[String] $cert_name       = undef,
  # Private Key options
  Optional[String] $priv_key        = undef,
  Optional[String] $priv_key_dir    = undef,
  Optional[String] $priv_key_group  = undef,
  Optional[String] $priv_key_owner  = undef,
  Stdlib::Filemode $priv_key_mode   = '0600',
  Optional[String] $priv_key_name   = undef,
  Boolean $manage_files             = true,
  Optional[Integer] $regenerate_ttl = undef,
  Optional[String]  $secret_engine  = undef,
) {
  # ONLY ON WINDOWS
  #
  # Because Windows is "special" and the paths to its certificates contain
  # the "thumbprint" aka the "hash" of the certificate in the last component:
  #  Example: Cert:\LocalMachine\My\ABCDEF1234568990
  #
  # This thumbprint/hash is unique to a certificate and is needed by subsequent
  # resources, such as an iis_site {}, in order to properly select the correct
  # certificate from the cert store.
  #
  # Puppet does not provide the ability to, at run time, "return" variables/state
  # that is generated from a resource. For instance, if we generate a new certificate
  # from our vault_cert resource at execution time, we're not able to access
  # the resulting attributes of this certificite (ie. its thumbprint). This would
  # mean if we solely relied on the vault_cert {} resource we would need a fact
  # to pickup the certificate thumbprint on the next puppet run. Any resources
  # that depended on the thumbprint value would require two puppet runs to be properly
  # configured (first run generates the cert, second run reads the thumbprint and
  # properly configures downstream resources). This is not ideal.
  #
  # To overcome this, only needed on Windows, we can genearte a certificate
  # from a Puppet function which is executed on the Master during catalog compilation.
  # This function will reach out to Vault, check for validity as normal and return
  # to us our certificate data along with the thumbprint information.
  # We take the generated certificate from the function as pass it into vault_cert{}.
  # Vault_cert{} sees that we pass it certificate data, so it bypasses contacting
  # the Vault server and simply writes that data to the Cert store.
  #
  # We then expose the $thumbprint, returned by the vault::cert() function,
  # as a variable/attribute of this vault::cert {} resource. This variable/attribute
  # and can be accessed by downstream resources on the first pass.
  $certs_details = $certs.reduce({}) |$memo, $c| {
    # unpack tuple
    $common_name = $c[0]
    $cert_options = $c[1]

    if $facts['os']['family'] == 'windows' {
      # use serial number provided in the parameters
      if $cert_options['serial_number'] {
        $serial_number = $cert_options['serial_number']
      }
      # check if the cert is existing and available as a fact
      elsif $facts['vault_existing_certs'] {
        $matching_certs = $facts['vault_existing_certs'].filter |$path, $cert_info| {
          $cert_info['common_name'] == $common_name
        }
        if !$matching_certs.empty() {
          $serial_number = $matching_certs[0]['serial_number']
        }
        else {
          $serial_number = undef
        }
      }
      # cert isn't currently defined/known
      else {
        $serial_number = undef
      }
      $details = vault::cert($common_name,
                              $api_server,
                              $api_token,
                              $secret_role,
                              $serial_number,
                              $common_name,
                              $cert_options['alt_names'],
                              $cert_options['ip_sans'],
                              $api_port,
                              $api_scheme,
                              $cert_ttl,
                              $regenerate_ttl,
                              $secret_engine)
    }
    else {
      $details = {
        cert => undef,
        priv_key => undef,
        thumbprint => undef,
        serial_number => undef,
      }
    }
    $memo + {$common_name => $details}
  }
}
