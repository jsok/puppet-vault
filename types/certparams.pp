type Vault::CertParams = Struct[{
  common_name       => String,
  api_secret_role   => String,
  api_server        => String,
  api_token         => String,
  alt_names         => Optional[Array[String]],
  ip_sans           => Optional[Array[String]],
  api_scheme        => Optional[String],
  api_port          => Optional[Integer],
  api_secret_engine => Optional[String],
  cert_ttl          => Optional[String],
  regenerate_ttl    => Optional[Integer],
  serial_number     => Optional[String],
}]
