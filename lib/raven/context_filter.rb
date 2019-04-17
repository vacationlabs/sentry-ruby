module Raven
  class ContextFilter
    ACTIVEJOB_RESERVED_PREFIX = "_aj_".freeze
    HAS_GLOBALID = const_defined?('GlobalID')

    class << self
      # Once an ActiveJob is queued, ActiveRecord references get serialized into
      # some internal reserved keys, such as _aj_globalid.
      #
      # The problem is, if this job in turn gets queued back into ActiveJob with
      # these magic reserved keys, ActiveJob will throw up and error. We want to
      # capture these and mutate the keys so we can sanely report it.
      def filter(context)
        case context
        when Array
          context.map { |arg| filter(arg) }
        when Hash
          context.each_with_object({}) do |(key, value), hash|
            next hash if key[0..3] == ACTIVEJOB_RESERVED_PREFIX
            hash[key] = filter(value)
          end
        else
          format_globalid(context)
        end
      end

      private

      def format_globalid(context)
        if HAS_GLOBALID && context.is_a?(GlobalID)
          context.to_s
        else
          context
        end
      end
    end
  end
end
