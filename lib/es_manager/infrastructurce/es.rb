# frozen_string_literal: true

require 'elasticsearch'
module EsManager
  module Infrastructure
    class Es
      def self.client
        @client ||= Elasticsearch::Client.new(url: ENV.fetch('ELASTICSEARCH_URL'), log: true)
      end
    end
  end
end
