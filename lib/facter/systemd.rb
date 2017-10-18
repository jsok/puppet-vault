# Fact: systemd_version
#
# Purpose:
#   Determine the version of systemd installed
#
# Resolution:
#  Check the output of systemctl --version

Facter.add(:systemd_version) do
  setcode do
    Facter::Util::Resolution.exec("systemctl --version")[/[0-9]+(\.[0-9]+)*/].to_i
  end
end
