module DelayedPaperclip
  module Attachment

    def self.included(base)
      base.send :include, InstanceMethods
      base.send :attr_accessor, :job_is_processing
      base.alias_method_chain :post_processing, :delay
      base.alias_method_chain :post_processing=, :delay
      base.alias_method_chain :save, :prepare_enqueueing
      base.alias_method_chain :most_appropriate_url, :processed
      base.alias_method_chain :post_process_styles, :processing
    end

    module InstanceMethods

      def post_processing_with_delay
        !delay_processing?
      end

      def post_processing_with_delay=(value)
        @post_processing_with_delay = value
      end

      def delayed_options
        @instance.class.attachment_definitions[@name][:delayed]
      end

      def delay_processing?
        if @post_processing_with_delay.nil?
          !!delayed_options
        else
           !@post_processing_with_delay
        end
      end

      def processing?
        @instance.send(:"#{@name}_processing?")
      end

      def process_delayed!
        self.job_is_processing = true
        reprocess!
        self.job_is_processing = false
      end

      def post_process_styles_with_processing(*args)
        post_process_styles_without_processing(*args)
        # update_column is available in rails 3.1 instead we can do this to update the attribute without callbacks
        #instance.update_column("#{name}_processing", false) if instance.respond_to?(:"#{name}_processing?")

        if instance.respond_to?(:"#{name}_processing?")
          instance.send("#{name}_processing=", false)
          instance.class.update_all({ "#{name}_processing" => false }, instance.class.primary_key => instance.id)
        end
      end

      def save_with_prepare_enqueueing
        was_dirty = @dirty
        save_without_prepare_enqueueing.tap do
          if delay_processing? && was_dirty
            instance.prepare_enqueueing_for name
          end
        end
      end

      def most_appropriate_url_with_processed
        if original_filename.nil? || delayed_default_url?
          default_url
        else
          @options.url
        end
      end

      def delayed_default_url?
        !(job_is_processing || dirty? || !delayed_options.try(:[], :url_with_processing) || !(@instance.respond_to?(:"#{name}_processing?") && processing?))
      end

    end
  end
end
