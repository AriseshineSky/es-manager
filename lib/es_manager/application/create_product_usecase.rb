# frozen_string_literal: true

module EsManager
  module Application
    class CreateProductUseCase
      def initialize(product_repo = Infrastructure::Product.new)
        @repo = product_repo
      end

      def execute(command)
        product = Domain::Product.new(
          id: command.id,
          name: command.name,
          price: command.price
        )
        @repo.bulk_insert([product.to_h])
      end
    end
  end
end

