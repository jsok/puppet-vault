type Vault::CertDetails = Struct[{
  thumbprint    => String,
  serial_number => String,
  common_name   => String,
  not_after     => String,
  not_before    => String,
  subject       => String,
}]
