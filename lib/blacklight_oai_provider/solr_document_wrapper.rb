module BlacklightOaiProvider
  class SolrDocumentWrapper < ::OAI::Provider::Model
    attr_reader :model, :timestamp_field
    attr_accessor :options, :extra_controller_params
    def initialize(controller, options = {})
      @controller = controller

      defaults = { :timestamp => 'timestamp', :limit => 15} 
      @options = defaults.merge options

      @timestamp_field = @options[:timestamp]
      @limit = @options[:limit]
      @extra_controller_params = {}
    end

    def sets
    end

    def earliest
      Time.parse @controller.get_search_results({:sort => @timestamp_field +' asc', :rows => 1}, extra_controller_params).last.first.get(@timestamp_field)
    end

    def latest
      Time.parse @controller.get_search_results({:sort => @timestamp_field +' desc', :rows => 1}, extra_controller_params).last.first.get(@timestamp_field)
    end

    def find(selector, options={})
      return next_set(options[:resumption_token]) if options[:resumption_token]

      if :all == selector
        response, records = @controller.get_search_results({:sort => @timestamp_field + ' asc', :per_page => @limit}, extra_controller_params)

        if @limit && response.total >= @limit
          return select_partial(OAI::Provider::ResumptionToken.new(options.merge({:last => 0})))
        end
      else                                                    
        records = @controller.get_search_results({:phrase_filters => {:id => selector.split('/', 2).last}}, extra_controller_params).last.first
      end
      records
    end

    def select_partial token
      records = @controller.get_search_results({:sort => @timestamp_field + ' asc', :per_page => @limit, :page => token.last}, extra_controller_params).last

      raise ::OAI::ResumptionTokenException.new unless records

      OAI::Provider::PartialResult.new(records, token.next(token.last+1))
    end

    def next_set(token_string)
      raise ::OAI::ResumptionTokenException.new unless @limit

      token = OAI::Provider::ResumptionToken.parse(token_string)
      select_partial(token)
    end
  end
end
