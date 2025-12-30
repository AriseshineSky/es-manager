# frozon_string_literal: true

require 'thread'

module EsManager
  module Application
    class MigrateUseCase
      MAPPING = {
        settings: {
          'index.mapping.total_fields.limit' => 1000
        },
        mappings: {
          dynamic: true,
          dynamic_templates: [
            {
              strings_as_keyword: {
                match_mapping_type: 'string',
                mapping: { type: 'keyword', ignore_above: 256 }
              }
            }
          ],
          properties: {
            asin: { type: 'keyword' },
            title: { type: 'text' },
            brand: { type: 'keyword' },
            manufacturer: { type: 'keyword' },
            binding: { type: 'keyword' },
            productTypes: { type: 'object', enabled: false },
            deleted: { type: 'boolean' },
            publication_date: { type: 'date' },
            attributes: { type: 'object', enabled: false },
            classifications: { type: 'object', enabled: false },
            relationships: { type: 'object', enabled: false },
            salesRanks: { type: 'object', enabled: false },
            sales_rank: { type: 'object', enabled: false },
            sales_ranks: { type: 'object', enabled: false },
            summaries: { type: 'object', enabled: false },
            identifiers: { type: 'object', enabled: false },
            images: { type: 'object', enabled: false },
            spapi_marketplace: { type: 'keyword' },
            fetched_at: { type: 'date' }
          }
        }
      }

      def initialize(old_index:, new_index:, alias_name:, repository: Infrastructure::Product)
        @old_index = old_index
        @new_index = new_index
        @alias_name = alias_name
        @repo = repository.new(index: old_index)
        @batch_queue = Queue.new
      end

      def execute(batch_size: 1000, concurrency: 4)
        prepare_new_index

        puts "Start migrating #{@old_index} → #{@new_index}"

        Thread.new do
          @repo.scroll_all(batch_size: batch_size) do |batch|
            @batch_queue << batch
          end
          concurrency.times { @batch_queue << :END }
        end

        workers = concurrency.times.map do
          Thread.new do
            loop do
              batch = @batch_queue.pop
              break if batch == :END

              @repo.bulk_insert(batch, new_index: @new_index)
              puts "Migrated batch size: #{batch.size}"
            end
          end
        end

        workers.each(&:join)

        # 切换 alias，零停机
        @repo.switch_alias(@alias_name, @new_index)

        puts 'Migration completed'
      end

      private

      def prepare_new_index
        client = EsManager::Infrastructure::Es.client
        if client.indices.exists?(index: @new_index)
          puts "Index #{@new_index} already exists, skipping creation"
          return
        end

        client.indices.create(index: @new_index, body: MAPPING)
        puts "Created new index #{@new_index} with mapping"
      end
    end
  end
end
