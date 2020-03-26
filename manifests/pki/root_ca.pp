# == (Private) Class to create and configure root certificate of authority
define vault::pki::root_ca (
  Optional[Hash]      $cert_options          = undef,
  String              $common_name           = undef,
  Optional[Hash]      $options               = undef,
  String              $path                  = undef,
  Optional[String]    $role_name             = undef,
  Optional[Hash]      $role_options          = undef,
  String              $token                 = $vault::token,
  Optional[String]    $ttl                   = '720h',
  String              $vault_addr            = $vault::vault_address,
) {

  ## Initialize pki secrets engine
  vault::secrets::engine { $path: 
    engine  => 'pki',
    token   => $token,
    options => {
      #'default-lease-ttl' => (string),
      'max-lease-ttl' => $ttl,
    },
  }
  
  ## Generate root public and private certs
  vault::pki::generate_cert { $path:
    token       => $token,
    common_name => $common_name,
    pkey_mode   => 'exported',
    options     => $cert_options,
    ttl         => $ttl,
    is_root_ca  => true,
  }

  ## Configure root CA urls
  vault::pki::config { $path:
    action  => 'write',
    path    => "${path}/config/urls",
    options => {
      'issuing_certificates'    => "http://${vault_addr}/v1/${path}/ca/pem",
      'crl_distribution_points' => "http://${vault_addr}/v1/${path}/crl/pem",
      #'ocsp_servers'           => (slice),
    },
    token   => $token,
  }

  ## Configure role for root CA
  if $role_name != undef {
    vault::pki::config { "${path}_role":
      action  => 'write',
      path    => "${path}/roles/${role_name}",
      options => $role_options,
      token   => $token,
    }
  }

  ## Configure root CA role.
  # allow_any_name (false) 
  # ======================
  #   If set, clients can request certificates for any CN they like. See the
  #   documentation for more information.
  #
  # allow_bare_domains (false)
  # ==========================
  #   If set, clients can request certificates for the base domains themselves,
  #   e.g. "example.com".  This is a separate option as in some cases this can
  #   be considered a security threat.  
  #
  # allow_glob_domains (false)
  # ==========================
  #   If set, domains specified in "allowed_domains" can include glob patterns,
  #   e.g. "ftp*.example.com". See the documentation for more information.
  #
  # allow_ip_sans (true)
  # ====================
  #   If set, IP Subject Alternative Names are allowed.  Any valid IP is accepted.
  #
  # allow_localhost (true)
  # ======================
  #   Whether to allow "localhost" as a valid common name in a request
  #
  # allow_subdomains (false)
  # ========================
  #   If set, clients can request certificates for subdomains of the CNs allowed
  #   by the other role options, including wildcard subdomains. See the docu-
  #   mentation for more information.
  #
  # allowed_domains ([])
  # ====================
  #   If set, clients can request certificates for subdomains directly beneath
  #   these domains, including the wildcard subdomains. See the documentation for
  #   more information. This parameter accepts a comma-separated string or list
  #   of domains.
  #
  # allowed_other_sans ("")
  # =======================
  #   If set, an array of allowed other names to put in SANs. These values support
  #   globbing and must be in the format <oid>;<type>:<value>. Currently only
  #   "utf8" is a valid type. All values, including globbing values, must use this
  #   syntax, with the exception being a single "*" which allows any OID and any
  #   value (but type must still be utf8).
  #
  # allowed_serial_numbers ("")
  # ===========================
  #   If set, an array of allowed serial numbers to put in Subject. These values
  #   support globbing.
  #
  # allowed_uri_sans ("")
  # =====================
  #   If set, an array of allowed URIs to put in the URI Subject Alternative Names.
  #   Any valid URI is accepted, these values support globbing.
  #
  # backend (string)
  # ================
  #   Backend Type
  #
  # basic_constraints_valid_for_non_ca (false)
  # ==========================================
  #   Mark Basic Constraints valid when issuing non-CA certificates.
  #
  # client_flag (true)
  # ==================
  #   If set, certificates are flagged for client auth use. Defaults to true.
  #
  # code_signing_flag (false)
  # =========================
  #   If set, certificates are flagged for code signing use. Defaults to false.
  #
  # country ("")
  # ============
  #   If set, Country will be set to this value in certificates issued by this role.
  #
  # email_protection_flag (false)
  # =============================
  #   If set, certificates are flagged for email protection use. Defaults to false.
  #
  # enforce_hostnames (true)
  # ========================
  #   If set, only valid host names are allowed for CN and SANs. Defaults to true.
  #
  # ext_key_usage ([])
  # ==================
  #   A comma-separated string or list of extended key usages. Valid values can be
  #   found at https://golang.org/pkg/crypto/x509/#ExtKeyUsage -- simply drop the
  #   "ExtKeyUsage" part of the name.  To remove all key usages from being set,
  #   set this value to an empty list.
  #
  # ext_key_usage_oids ("")
  # =======================
  #   A comma-separated string or list of extended key usage oids.
  #
  # generate_lease (false)
  # ======================
  #   If set, certificates issued/signed against this role will have Vault leases
  #   attached to them. Defaults to "false". Certificates can be added to the CRL by
  #   "vault revoke <lease_id>" when certificates are associated with leases.  It can
  #   also be done using the "pki/revoke" endpoint. However, when lease generation is
  #   disabled, invoking "pki/revoke" would be the only way to add the certificates
  #   to the CRL.  When large number of certificates are generated with long
  #   lifetimes, it is recommended that lease generation be disabled, as large amount
  #   of leases adversely affect the startup time of Vault.
  #
  # key_bits (2048)
  # ===============
  #   The number of bits to use. You will almost certainly want to change this if
  #   you adjust the key_type.
  #
  # key_type ("rsa')
  # ================
  #   The type of key to use; defaults to RSA. "rsa" and "ec" are the only valid
  #   values.
  #
  # key_usage (['DigitalSignature', 'KeyAgreement', 'KeyEncipherment'])
  # =================
  #   A comma-separated string or list of key usages (not extended key usages).
  #   Valid values can be found at https://golang.org/pkg/crypto/x509/#KeyUsage
  #   -- simply drop the "KeyUsage" part of the name.  To remove all key usages
  #   from being set, set this value to an empty list.
  #
  # locality ("")
  # =============
  #   If set, Locality will be set to this value in certificates issued by this
  #   role.
  #
  # max_ttl ("")
  # ============
  #   The maximum allowed lease duration 
  #
  # name ("")
  # =========
  #   Name of the role
  #
  # no_store (false)
  # ================
  #   If set, certificates issued/signed against this role will not be stored in
  #   the storage backend. This can improve performance when issuing large numbers
  #   of certificates. However, certificates issued in this way cannot be enumerated
  #   or revoked, so this option is recommended only for certificates that are
  #   non-sensitive, or extremely short-lived. This option implies a value of "false"
  #   for "generate_lease".
  #
  # not_before_duration (duration "30s')
  # ====================================
  #   The duration before now the cert needs to be created / signed.
  #
  # organization ("")
  # =================
  #   If set, O (Organization) will be set to this value in certificates issued by
  #   this role.
  #
  # ou ("")
  # =======
  #   If set, OU (OrganizationalUnit) will be set to this value in certificates
  #   issued by this role.
  #
  # policy_identifiers ([])
  # =======================
  #   A comma-separated string or list of policy oids.
  #
  # postal_code ("")
  # ================
  #   If set, Postal Code will be set to this value in certificates issued by
  #   this role.
  #
  # province ("")
  # =============
  #   If set, Province will be set to this value in certificates issued by this role.
  #
  # require_cn (true)
  # =================
  #   If set to false, makes the 'common_name' field optional while generating a
  #   certificate.
  #
  # server_flag (true)
  # ==================
  #   If set, certificates are flagged for server auth use.  Defaults to true.
  #
  # street_address ("")
  # ===================
  #   If set, Street Address will be set to this value in certificates issued by
  #   this role.
  #
  # ttl (duration "")
  # =================
  #   The lease duration if no specific lease duration is requested. The lease
  #   duration controls the expiration of certificates issued by this backend.
  #   Defaults to the value of max_ttl.
  #
  # use_csr_common_name (true)
  # ==========================
  #   If set, when used with a signing profile, the common name in the CSR will
  #   be used. This does *not* include any requested Subject Alternative Names.
  #   Defaults to true.
  #
  # use_csr_sans (true)
  # ===================
  #   If set, when used with a signing profile, the SANs in the CSR will be used.
  #   This does *not* include the Common Name (cn). Defaults to true.

}
