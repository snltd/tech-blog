def symbolize_keys(hash)
  #
  # because, IMO, keys should usually be symbols
  #
  Hash[hash.map{ |(k, v)| [k.to_sym,v] }]
end
