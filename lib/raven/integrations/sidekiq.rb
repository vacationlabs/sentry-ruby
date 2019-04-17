require 'time'
require 'sidekiq'

require 'raven/context_filter'

module Raven
  class SidekiqCleanupMiddleware
    def call(_worker, job, queue)
      Raven.context.transaction.push "Sidekiq/#{job['class']}"
      Raven.extra_context(:sidekiq => job.merge("queue" => queue))
      yield
      Context.clear!
      BreadcrumbBuffer.clear!
    end
  end

  class SidekiqErrorHandler
    def call(ex, context)
      context = Raven::ContextFilter.filter(context)
      Raven.context.transaction.push transaction_from_context(context)
      Raven.capture_exception(
        ex,
        :message => ex.message,
        :extra => { :sidekiq => context }
      )
      Context.clear!
      BreadcrumbBuffer.clear!
    end

    private

    # this will change in the future:
    # https://github.com/mperham/sidekiq/pull/3161
    def transaction_from_context(context)
      classname = (context["wrapped"] || context["class"] ||
                    (context[:job] && (context[:job]["wrapped"] || context[:job]["class"]))
                  )
      if classname
        "Sidekiq/#{classname}"
      elsif context[:event]
        "Sidekiq/#{context[:event]}"
      else
        "Sidekiq"
      end
    end
  end
end

if Sidekiq::VERSION > '3'
  Sidekiq.configure_server do |config|
    config.error_handlers << Raven::SidekiqErrorHandler.new
    config.server_middleware do |chain|
      chain.add Raven::SidekiqCleanupMiddleware
    end
  end
end
