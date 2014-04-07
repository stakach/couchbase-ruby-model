module Couchbase
  module ActiveModel

    def self.included(base)
      base.class_eval do
        extend ::ActiveModel::Callbacks
        extend ::ActiveModel::Naming
        include ::ActiveModel::Conversion
        include ::ActiveModel::Validations
        include ::ActiveModel::Validations::Callbacks
        include ::ActiveModel::Dirty
        include ::ActiveModel::Serializers::JSON


        # Overrides the default active model serializable_hash as it makes the assumption that
        # attributes.keys are strings and we need to include the model id
        def serializable_hash(options = nil)
          options ||= {}

          attribute_names = attributes.keys << :id
          if only = options[:only]
            attribute_names &= Array(only).map(&:to_sym)
          elsif except = options[:except]
            attribute_names -= Array(except).map(&:to_sym)
          end

          hash = {}
          attribute_names.each { |n| hash[n] = read_attribute_for_serialization(n) }

          Array(options[:methods]).each { |m| hash[m.to_s] = send(m) if respond_to?(m) }

          serializable_add_includes(options) do |association, records, opts|
            hash[association.to_s] = if records.respond_to?(:to_ary)
              records.to_ary.map { |a| a.serializable_hash(opts) }
            else
              records.serializable_hash(opts)
            end
          end

          hash
        end


        define_model_callbacks :create, :update, :delete, :save, :initialize
        [:save, :create, :update, :delete, :initialize].each do |meth|
          class_eval <<-EOC
            alias #{meth}_without_callbacks #{meth}
            def #{meth}(*args, &block)
              run_callbacks(:#{meth}) do
                #{meth}_without_callbacks(*args, &block)
              end
            end
          EOC
        end
      end
    end

    # Public: Allows for access to ActiveModel functionality.
    #
    # Returns self.
    def to_model
      self
    end

    # Public: Hashes our unique key instead of the entire object.
    # Ruby normally hashes an object to be used in comparisons.  In our case
    # we may have two techincally different objects referencing the same entity id,
    # so we will hash just the class and id (via to_key) to compare so we get the
    # expected result
    #
    # Returns a string representing the unique key.
    def hash
      to_param.hash
    end

    # Public: Overrides eql? to use == in the comparison.
    #
    # other - Another object to compare to
    #
    # Returns a boolean.
    def eql?(other)
      self == other
    end

    # Public: Overrides == to compare via class and entity id.
    #
    # other - Another object to compare to
    #
    # Example
    #
    #     movie = Movie.find(1234)
    #     movie.to_key
    #     # => 'movie-1234'
    #
    # Returns a string representing the unique key.
    def ==(other)
      hash == other.hash
    end

  end
end
