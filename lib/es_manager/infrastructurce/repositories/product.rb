# frozon_string_literal: true

module EsManager
  module Infrastructure
    class Product
      def initialize(index)
        @client = Es.client
        @index = index
      end

      def find_by_id(id)
        @client.get(index: @index, id: id)['_source']
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        nil
      end

      def scroll_all(batch_size: 1000)
        scroll = '2m'
        response = @client.search(
          index: @index,
          scroll: scroll,
          body: { query: { match_all: {} }, size: batch_size }
        )

        loop do
          hits = response['hits']['hits']
          break if hits.empty?

          yield hits.map { |h| h['_source'].merge(id: h['_id']) }

          scroll_id = response['_scroll_id']
          response = @client.scroll(scroll_id: scroll_id, scroll: scroll)
        end
      end

      def bulk_insert(records, new_index:)
        body = records.map { |r| { index: { _index: new_index, _id: r[:id], data: r } } }
        @client.bulk(body: body)
      end
    end
  end
end
