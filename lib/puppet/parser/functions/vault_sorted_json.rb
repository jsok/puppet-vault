require 'json'

def sorted_json(obj)
  case obj
  when Integer, Float, TrueClass, FalseClass, NilClass
    return obj.to_json
  when String
    # Convert quoted integers (string) to int
    (obj =~ %r{\A[-]?[0-9]+\z} ? obj.to_i : obj).to_json
  when Array
    arrayRet = []
    obj.each do |a|
      arrayRet.push(sorted_json(a))
    end
    '[' << arrayRet.join(',') << ']'
  when Hash
    ret = []
    obj.keys.sort.each do |k|
      ret.push(k.to_json << ':' << sorted_json(obj[k]))
    end
    '{' << ret.join(',') << '}'
  else
    raise Exception(format('Unable to handle object of type <%s>', obj.class.to_s))
  end
end

module Puppet::Parser::Functions
  newfunction(:vault_sorted_json, type: :rvalue, doc: <<-EOS
This function takes data, outputs making sure the hash keys are sorted
*Examples:*
    sorted_json({'key'=>'value'})
Would return: {'key':'value'}
    EOS
             ) do |arguments|
    if arguments.size != 1
      raise(Puppet::ParseError, 'sorted_json(): Wrong number of arguments ' \
        "given (#{arguments.size} for 1)")
    end
    json = arguments[0].delete_if { |_key, value| value == :undef }
    return sorted_json(json)
  end
end
