Facter.add(:vault_initialized) do
  setcode do
    if Facter::Core::Execution.which('vault')
      init_line = Facter::Core::Execution.execute('vault status | grep Initialized 2>&1')
      # initialized is now a string with the format:
      # Initialized      true
      # Initialized      false
      #
      # we are splitting this up into its parts by space
      init_parts = init_line.split(' ')
      # the second part is the value (a string)
      init_value = init_parts[1]
      # convert the string to a boolean, so if it's "true" it will return true otherwise false
      init_value.downcase == 'true'
    end
  end
end
