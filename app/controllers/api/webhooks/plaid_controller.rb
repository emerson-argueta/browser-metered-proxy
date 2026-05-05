module Api
  module Webhooks
    class PlaidController < ApplicationController
      skip_before_action :authenticate_actor!

      # POST /api/webhooks/plaid
      def receive
        case params[:webhook_type]
        when "TRANSFER"
          Rails.logger.info "Plaid transfer #{params[:transfer_id]} → #{params[:new_transfer_status]}"
        when "INCOME"
          Rails.logger.info "Plaid income webhook: #{params[:webhook_code]}"
        end

        head :ok
      end
    end
  end
end
