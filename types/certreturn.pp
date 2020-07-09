type Vault::CertReturn = Struct[{
  cert          => Optional[String],
  priv_key      => Optional[String],
  thumbprint    => Optional[String],
  serial_number => Optional[String],
}]
