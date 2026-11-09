require "base64"
require "yaml"

module Rmxp
  # Converts Marshal data to a plain YAML tree and back.
  #
  # The tree only contains Hash, Array, String, Integer, Float, true, false,
  # nil and a handful of tagged Hash nodes. It preserves:
  # - object classes and every instance variable (in declaration order),
  # - Ruby string encodings,
  # - shared references and cycles,
  # - the opaque payload of RGSS types (Table, Color, Tone, Rect, Font).
  #
  # The point is the round trip: load(data) then dump(data) must give the
  # same Marshal bytes, not merely an equal-looking object.
  module Codec
    FORMAT = 1
    IMMEDIATE = [NilClass, TrueClass, FalseClass, Integer, Float, Symbol].freeze

    module_function

    # Stub classes created while loading a file. A game's data files do not
    # always agree on a class shape (one build dumped a class with a custom
    # Marshal format, another dumped it as a plain object), so stubs are
    # reset between files.
    def track_class(name)
      @tracked ||= {}
      @tracked[name] = true
    end

    def reset_stubs!
      return unless @tracked

      @tracked.keys.sort_by { |name| -name.count("::") }.each { |name| remove_constant(name) }
      @tracked.clear
    end

    def remove_constant(name)
      parts = name.split("::")
      owner = Object
      parts[0..-2].each do |part|
        return unless owner.const_defined?(part, false)

        owner = owner.const_get(part, false)
      end
      owner.send(:remove_const, parts.last) if owner.const_defined?(parts.last, false)
    end

    # Raw Marshal bytes -> plain tree.
    def to_tree(value)
      state = Encoder.new
      { "format" => FORMAT, "value" => state.encode(value) }
    end

    # Plain tree -> object graph.
    def from_tree(tree)
      expected = tree["format"]
      raise ArgumentError, "format de données inconnu: #{expected.inspect}" unless expected == FORMAT

      Decoder.new.decode(tree["value"])
    end

    # Marshal streams start with the 4.8 format marker.
    def marshal?(bytes)
      bytes.start_with?("\x04\x08".b)
    end

    # Raw Marshal bytes -> plain tree (loading the bytes first).
    def dump_bytes(bytes)
      to_tree(load_bytes(bytes))
    end

    # Plain tree -> Marshal bytes.
    def load_tree_bytes(tree)
      Marshal.dump(from_tree(tree))
    end

    # Marshal.load that defines stub classes for unknown RPG data classes.
    #
    # RMXP data files reference classes that our tool does not implement.
    # Marshal refuses the load until the constant exists, so the class name
    # is taken from the error and a bare stub is created.
    BUILTIN_SUPERCLASSES = %w[Array Hash String].freeze

    # Defines a class whose Marshal payload is kept verbatim. It is used for
    # game classes that implement `_dump` (Essentials' OrderedHash and the
    # like): the tool does not need their contents to round-trip them.
    def define_blob_stub(name)
      parts = name.split("::")
      owner = Object
      parts.each_with_index do |part, index|
        last = index == parts.length - 1
        if last
          owner.send(:remove_const, part) if owner.const_defined?(part, false)
          klass = Class.new(RmxpBlob)
          owner.const_set(part, klass)
          track_class(name)
        else
          owner.const_set(part, Module.new) unless owner.const_defined?(part, false)
          owner = owner.const_get(part, false)
        end
      end
    end

    def load_bytes(bytes)
      attempts = 0
      # Classes stub'd as plain objects, in the order they were discovered.
      # A C-format object later needs one of them to inherit Array/Hash/String,
      # but Marshal does not say which class the failing object belongs to.
      candidates = []
      begin
        Marshal.load(bytes)
      rescue ArgumentError, TypeError => e
        undefined = e.message[/undefined class\/module (.+)\z/, 1]
        if undefined
          define_stub(undefined)
          candidates << [undefined, 0]
        elsif (needs_load = e.message[/class (.+) needs to have method `_load'/, 1])
          # The class defines its own Marshal format. Keep its payload
          # opaque: a blob class round-trips the bytes without needing to
          # understand the class.
          define_blob_stub(needs_load)
        elsif e.message.start_with?("dump format error")
          candidate = candidates.reverse.find { |(_, kind)| kind < BUILTIN_SUPERCLASSES.length }
          raise if candidate.nil?

          name, kind = candidate
          superclass = Object.const_get(BUILTIN_SUPERCLASSES[kind])
          define_stub(name, superclass: superclass)
          candidate[1] += 1
        else
          raise
        end
        attempts += 1
        raise if attempts >= 300

        retry
      end
    end

    # Defines (or reuses) a constant with an empty class. Nested names are
    # created one level at a time: RPG::Animation::Frame needs RPG and
    # RPG::Animation as containers first.
    def define_stub(name, superclass: nil)
      parts = name.split("::")
      owner = Object
      parts.each_with_index do |part, index|
        last = index == parts.length - 1
        if last
          owner.send(:remove_const, part) if superclass && owner.const_defined?(part, false)
          existing = owner.const_defined?(part, false) ? owner.const_get(part, false) : nil
          unless existing
            owner.const_set(part, Class.new(superclass || Object))
            track_class(name)
          end
        elsif !owner.const_defined?(part, false)
          owner.const_set(part, Module.new)
        end
        owner = owner.const_get(part, false) unless last
      end
    end

    class Encoder
      def initialize
        @counts = Hash.new(0)
        @seen = {}
        @ids = {}
        @next_id = 0
      end

      def encode(value)
        count_refs(value)
        encode_value(value)
      end

      private

      def reference?(value)
        !IMMEDIATE.include?(value.class)
      end

      def count_refs(value)
        return unless reference?(value)

        id = value.object_id
        @counts[id] += 1
        return if @seen[id]

        @seen[id] = true
        each_child(value) { |child| count_refs(child) }
      end

      def each_child(value)
        children = []
        if value.is_a?(RmxpBlob) || value.instance_of?(String)
          nil
        elsif value.instance_of?(Array)
          value.each { |child| children << child }
        elsif value.is_a?(Array)
          value.each { |child| children << child }
          children.concat(ivar_values(value))
        elsif value.instance_of?(Hash)
          value.each_pair { |key, child| children << key << child }
        elsif value.is_a?(Hash)
          value.each_pair { |key, child| children << key << child }
          children.concat(ivar_values(value))
        elsif value.is_a?(String)
          children.concat(ivar_values(value))
        else
          children.concat(ivar_values(value))
        end
        children.each { |child| yield child }
      end

      def ivar_values(value)
        value.instance_variables.map { |ivar| value.instance_variable_get(ivar) }
      end

      def encode_value(value)
        if value.nil? || value.equal?(true) || value.equal?(false)
          value
        elsif value.instance_of?(Integer)
          value
        elsif value.instance_of?(Float)
          encode_float(value)
        elsif value.instance_of?(Symbol)
          { "__sym__" => value.to_s }
        elsif value.instance_of?(String)
          wrap_ref(value) { encode_string(value) }
        elsif value.instance_of?(Array)
          wrap_ref(value) { value.map { |child| encode_value(child) } }
        elsif value.instance_of?(Hash)
          wrap_ref(value) { encode_hash(value) }
        elsif value.is_a?(Array)
          wrap_ref(value) { encode_array_subclass(value) }
        elsif value.is_a?(Hash)
          wrap_ref(value) { encode_hash_subclass(value) }
        elsif value.is_a?(String)
          wrap_ref(value) { encode_string_subclass(value) }
        elsif value.instance_of?(Time)
          wrap_ref(value) { { "__time__" => Base64.strict_encode64(Marshal.dump(value)) } }
        else
          wrap_ref(value) { encode_object(value) }
        end
      end

      def wrap_ref(value)
        return yield if @counts[value.object_id] <= 1

        id = @ids[value.object_id]
        return { "__ref__" => id } if id

        id = (@ids[value.object_id] = @next_id)
        @next_id += 1
        node = yield
        node = { "__str__" => node } if node.is_a?(String)
        node = { "__array__" => node } unless node.is_a?(Hash)
        { "__id__" => id }.merge(node)
      end

      def encode_float(value)
        if value.nan?
          { "__float__" => "NaN" }
        elsif value.infinite? == 1
          { "__float__" => "Infinity" }
        elsif value.infinite? == -1
          { "__float__" => "-Infinity" }
        else
          value
        end
      end

      # UTF-8 strings stay readable; other encodings keep their bytes and
      # name. ASCII-only binary strings are still readable.
      def encode_string(value)
        if value.encoding == Encoding::UTF_8 && value.valid_encoding?
          value
        elsif value.ascii_only?
          { "__str__" => value, "__enc__" => value.encoding.name }
        else
          { "__b64__" => Base64.strict_encode64(value), "__enc__" => value.encoding.name }
        end
      end

      def encode_hash(value)
        pairs = value.map { |key, child| [encode_value(key), encode_value(child)] }
        node = { "__hash__" => pairs }
        default = value.default
        node["__default__"] = encode_value(default) unless default.nil?
        node
      end

      def encode_array_subclass(value)
        node = { "__class__" => value.class.name, "__builtin__" => "Array",
                 "__array__" => value.map { |child| encode_value(child) } }
        add_ivars(node, value)
      end

      def encode_hash_subclass(value)
        pairs = value.map { |key, child| [encode_value(key), encode_value(child)] }
        node = { "__class__" => value.class.name, "__builtin__" => "Hash", "__hash__" => pairs }
        node["__default__"] = encode_value(value.default) unless value.default.nil?
        add_ivars(node, value)
      end

      def encode_string_subclass(value)
        content = encode_string(String.new(value))
        node = { "__class__" => value.class.name, "__builtin__" => "String" }
        if content.is_a?(Hash)
          node.merge!(content)
        else
          node["__str__"] = content
        end
        add_ivars(node, value)
      end

      def add_ivars(node, value)
        ivars = value.instance_variables
        return node if ivars.empty?

        node["__ivars__"] = ivars.to_h { |ivar| [ivar.to_s, encode_value(value.instance_variable_get(ivar))] }
        node
      end

      def encode_object(value)
        if value.is_a?(RmxpBlob)
          raise "blob sans payload: #{value.class.name}" if value.payload.nil?

          return { "__class__" => value.class.name, "__blob__" => Base64.strict_encode64(value.payload) }
        end

        node = { "__class__" => value.class.name }
        ivars = value.instance_variables
        unless ivars.empty?
          node["__ivars__"] = ivars.to_h { |ivar| [ivar.to_s, encode_value(value.instance_variable_get(ivar))] }
        end
        node
      end
    end

    class Decoder
      def initialize
        @cache = {}
      end

      def decode(node)
        case node
        when nil, true, false, Integer, Float, String
          node
        when Array
          node.map { |child| decode(child) }
        when Hash
          decode_hash(node)
        else
          raise ArgumentError, "nœud YAML inattendu: #{node.class}"
        end
      end

      private

      def decode_hash(node)
        return @cache.fetch(node["__ref__"]) if node.key?("__ref__")

        if node.key?("__sym__")
          node["__sym__"].to_sym
        elsif node.key?("__float__")
          decode_float(node["__float__"])
        elsif node.key?("__time__")
          register(node, Marshal.load(Base64.strict_decode64(node["__time__"])))
        elsif node.key?("__class__")
          decode_object(node)
        elsif node.key?("__str__") || node.key?("__b64__")
          register(node, decode_string_node(node))
        elsif node.key?("__array__")
          array = []
          register(node, array)
          node["__array__"].each { |child| array << decode(child) }
          array
        elsif node.key?("__hash__")
          hash = {}
          register(node, hash)
          node["__hash__"].each { |key, child| hash[decode(key)] = decode(child) }
          hash.default = decode(node["__default__"]) if node.key?("__default__")
          hash
        else
          # Plain YAML mapping: string keys, string values, as written by
          # hand for the manifest. Data trees never rely on this form.
          node.to_h { |key, child| [key, decode(child)] }
        end
      end

      def register(node, object)
        @cache[node["__id__"]] = object if node.key?("__id__")
        object
      end

      def build_string(value, encoding_name)
        string = value.dup
        string.force_encoding(encoding_name) if encoding_name
        string
      end

      def decode_float(name)
        case name
        when "NaN" then Float::NAN
        when "Infinity" then Float::INFINITY
        when "-Infinity" then -Float::INFINITY
        else raise ArgumentError, "float spécial inconnu: #{name}"
        end
      end

      def decode_object(node)
        class_name = node["__class__"]
        if node.key?("__blob__")
          klass = blob_class(class_name)
          value = klass._load(Base64.strict_decode64(node["__blob__"]))
          return register(node, value)
        end

        builtin = node["__builtin__"]
        klass = object_class(class_name, builtin)
        value = klass.allocate
        register(node, value)
        case builtin
        when "Array"
          node.fetch("__array__", []).each { |child| value << decode(child) }
        when "Hash"
          node.fetch("__hash__", []).each { |key, child| value[decode(key)] = decode(child) }
          value.default = decode(node["__default__"]) if node.key?("__default__")
        when "String"
          value.replace(decode_string_node(node))
        end
        node.fetch("__ivars__", {}).each do |name, child|
          value.instance_variable_set(name, decode(child))
        end
        value
      end

      # A class whose Marshal payload is opaque (defined while loading:
      # OrderedHash, WordArray, ...). Build starts from YAML in a fresh
      # process, so the constant has to be created again.
      def blob_class(name)
        parts = name.split("::")
        owner = Object
        parts.each_with_index do |part, index|
          last = index == parts.length - 1
          existing = owner.const_defined?(part, false) ? owner.const_get(part, false) : nil
          if last
            return existing if existing.is_a?(Class) && existing <= RmxpBlob

            owner.send(:remove_const, part) if existing
            klass = Class.new(RmxpBlob)
            owner.const_set(part, klass)
            Codec.track_class(name)
            return klass
          end
          unless existing
            existing = Module.new
            owner.const_set(part, existing)
          end
          owner = existing
        end
        owner
      end

      def decode_string_node(node)
        if node.key?("__b64__")
          build_string(Base64.strict_decode64(node["__b64__"]), node["__enc__"])
        else
          build_string(node["__str__"], node["__enc__"])
        end
      end

      # Constants are defined by Codec.load_bytes while the data was being
      # loaded. A build starts from the YAML alone, so define them here too.
      def object_class(name, builtin = nil)
        parts = name.split("::")
        owner = Object
        parts.each_with_index do |part, index|
          last = index == parts.length - 1
          existing = owner.const_defined?(part, false) ? owner.const_get(part, false) : nil
          if last
            if builtin
              superclass = Object.const_get(builtin)
              if existing.is_a?(Class) && existing <= superclass
                return existing
              end

              owner.send(:remove_const, part) if existing
              klass = Class.new(superclass)
              owner.const_set(part, klass)
              Codec.track_class(name)
              return klass
            end
            return existing if existing

            klass = Class.new
            owner.const_set(part, klass)
            Codec.track_class(name)
            return klass
          end

          unless existing
            existing = Module.new
            owner.const_set(part, existing)
          end
          owner = existing
        end
        owner
      end
    end
  end
end
