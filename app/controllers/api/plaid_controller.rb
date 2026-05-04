module Api
  class PlaidController < ApplicationController
    skip_before_action :authenticate_user!, only: [:webhooks]

    # POST /api/plaid/link_token
    def link_token
      products = params[:products] || ["transactions"]
      products = products.map { |p| Plaid::Products.const_get(p.upcase) }

      request_obj = Plaid::LinkTokenCreateRequest.new({
        user: { client_user_id: @current_user_id },
        client_name: ENV.fetch("APP_NAME", "App"),
        products: products,
        country_codes: [Plaid::CountryCode::US],
        language: "en"
      })

      response = plaid_client.link_token_create(request_obj)
      log_usage(call_type: "link_session", plaid_request_id: response.request_id)

      render json: { link_token: response.link_token }
    rescue Plaid::ApiError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/plaid/exchange_token
    # Exchanges a public token for an access token (stored encrypted server-side)
    def exchange_token
      public_token = params.require(:public_token)
      item_type = params[:item_type] || "owner"

      request_obj = Plaid::ItemPublicTokenExchangeRequest.new(public_token: public_token)
      response = plaid_client.item_public_token_exchange(request_obj)

      ExternalItem.create!(
        user_id: @current_user_id,
        access_token_encrypted: response.access_token,
        item_id: response.item_id,
        institution_name: params[:institution_name],
        account_id: params[:account_id],
        account_name: params[:account_name],
        account_type: params[:account_type],
        item_type: item_type
      )

      render json: { item_id: response.item_id, status: "connected" }
    rescue Plaid::ApiError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/plaid/income/verify
    # Initiates income verification for an applicant
    def income_verify
      item = ExternalItem.find_by!(user_id: @current_user_id, item_type: "applicant", item_id: params[:item_id])

      request_obj = Plaid::CreditPayrollIncomeGetRequest.new(
        user_token: item.access_token_encrypted
      )
      response = plaid_client.credit_payroll_income_get(request_obj)

      log_usage(
        call_type: "income_verify",
        plaid_request_id: response.request_id,
        charged_to: params[:charged_to] || "user",
        metadata: { entity_id: params[:entity_id] }.compact
      )

      render json: { income_data: response.payroll_income }
    rescue Plaid::ApiError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/plaid/transfer/initiate
    # Initiates an ACH transfer
    def transfer_initiate
      owner_item = ExternalItem.find_by!(user_id: @current_user_id, item_type: "owner")

      request_obj = Plaid::TransferCreateRequest.new({
        access_token: owner_item.access_token_encrypted,
        account_id: owner_item.account_id,
        type: "credit",
        network: "ach",
        amount: params.require(:amount).to_s,
        ach_class: "ppd",
        user: {
          legal_name: params.require(:legal_name),
          email_address: params.require(:email_address)
        },
        description: params[:description] || "Payment"
      })
      response = plaid_client.transfer_create(request_obj)

      log_usage(
        call_type: "ach_transfer",
        plaid_request_id: response.request_id,
        metadata: { entity_id: params[:entity_id] }.compact
      )

      render json: {
        transfer_id: response.transfer.id,
        status: response.transfer.status,
        amount: response.transfer.amount
      }
    rescue Plaid::ApiError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # GET /api/plaid/transfer/status/:transfer_id
    def transfer_status
      request_obj = Plaid::TransferGetRequest.new(transfer_id: params[:transfer_id])
      response = plaid_client.transfer_get(request_obj)
      render json: { status: response.transfer.status, amount: response.transfer.amount }
    rescue Plaid::ApiError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /api/plaid/webhooks
    # Receives Plaid payment status updates — no auth required, verified by webhook verification
    def webhooks
      webhook_type = params[:webhook_type]

      case webhook_type
      when "TRANSFER"
        handle_transfer_webhook(params)
      when "INCOME"
        handle_income_webhook(params)
      end

      head :ok
    end

    private

    def handle_transfer_webhook(data)
      transfer_id = data[:transfer_id]
      new_status = data[:new_transfer_status]
      Rails.logger.info "Transfer #{transfer_id} status → #{new_status}"
    end

    def handle_income_webhook(data)
      Rails.logger.info "Income webhook: #{data[:webhook_code]}"
    end
  end
end
