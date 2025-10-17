class Utils
  def self.random_str(len)
    str = ""
    while str.length < len
      chr = OpenSSL::Random.random_bytes(1)
      ord = chr.unpack1("C")

      #          0            9              A            Z              a            z
      if ord.between?(48, 57) || ord.between?(65, 90) || ord.between?(97, 122)
        str += chr
      end
    end

    str
  end

  def silence_stream(*streams)
    on_hold = streams.collect { |stream| stream.dup }
    streams.each do |stream|
      stream.reopen(File::NULL)
      stream.sync = true
    end
    yield
  ensure
    streams.each_with_index do |stream, i|
      stream.reopen(on_hold[i])
    end
  end
end
