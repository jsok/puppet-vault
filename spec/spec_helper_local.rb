# copied from Voxpupuli-test
# Generating facts is slow - this memoizes the facts between multiple classes.
# Marshalling is used to get unique instances which helps when tests overrides
# facts.
FACTS_CACHE = {} # rubocop:disable Style/MutableConstant
def on_supported_os(opts = {})
  result = FACTS_CACHE[opts.to_s] ||= super(opts)
  Marshal.load(Marshal.dump(result))
end
