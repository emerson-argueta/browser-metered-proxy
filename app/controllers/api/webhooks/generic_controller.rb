module Api
  module Webhooks
    class GenericController < ApplicationController
      skip_before_action :authenticate_actor!

      # POST /api/webhooks/:provider
      def receive
        Rails.logger.info "Webhook received — provider: #{params[:provider]}, payload: #{request.raw_post.truncate(500)}"
        head :ok
      end
    end
  end
end
